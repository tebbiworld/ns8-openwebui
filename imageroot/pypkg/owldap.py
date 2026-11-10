#
# Copyright (C) 2026 tebbi
# SPDX-License-Identifier: GPL-3.0-or-later
#

"""Translate the shared directory settings (pypkg/ldapsettings.py) into Open
WebUI's native LDAP_* environment.

Open WebUI binds the directory itself (open_webui/routers/auths.py); it does
not use a module binder. What it supports is narrower than the shared module
offers, which is why this translation lives in the module and not in the
shared ldapsettings.py:

  * only ``use_ssl`` (ldaps://), never StartTLS -> a custom server with
    StartTLS is refused by configure-module/05validate_ldap;
  * a single ``LDAP_SEARCH_FILTER`` that is AND-ed into the user lookup, with
    no group-name resolution -> a configured group is resolved to its DN here
    and turned into a memberOf filter.

Connection resolution (user domain through the node's ldapproxy, or a server
of its own) is reused 1:1 from ldapsettings.env_lines(), so this module picks
up the same loopback/bind handling as ns8-clamav and ns8-idevice-backup.
"""

import os
import sys

import ldap3
from ldap3.utils.conv import escape_filter_chars

import agent
import ldapsettings

TIMEOUT = 10

# A syntactically valid filter that matches no entry. When a group restriction
# is configured but cannot be resolved, it is AND-ed into the user search so
# every login is refused (fail closed) instead of letting everyone in.
_FAIL_CLOSED_FILTER = "(memberOf=CN=__openwebui_group_unresolved__)"


def _log(msg):
    print(msg, file=sys.stderr)


def _enabled():
    """The directory login is switched on (LDAP_ENABLED is a module flag)."""
    return os.environ.get("LDAP_ENABLED", "false").strip().lower() in ("1", "true")


def _resolved_connection():
    """Resolve the stored settings into the connection parameters, reusing
    ldapsettings so the loopback/bind handling stays identical to the other
    modules. Returns a dict, or None when the directory is not available."""
    kv = {}
    for line in ldapsettings.env_lines(active=True):
        if "=" in line:
            key, value = line.split("=", 1)
            kv[key] = value
    if not kv.get("LDAP_HOST"):
        # domain source whose user domain is currently unavailable: fail closed
        return None
    tls = kv.get("LDAP_TLS", "none")
    if tls == "starttls":
        # Open WebUI cannot do StartTLS; configure-module already refuses it,
        # so reaching here means a stale setting -> refuse rather than downgrade
        _log(agent.SD_WARNING + "Open WebUI does not support StartTLS: logins are refused")
        return None
    schema = kv.get("LDAP_SCHEMA", "ad")
    return {
        "source": kv.get("LDAP_SOURCE", "domain"),
        "host": kv["LDAP_HOST"],
        "port": int(kv.get("LDAP_PORT") or (636 if tls == "ssl" else 389)),
        "use_ssl": tls == "ssl",
        "tls_verify": kv.get("LDAP_TLS_VERIFY", "true").strip().lower() not in ("0", "false", "no", "off"),
        "schema": schema,
        "base_dn": kv.get("LDAP_BASE_DN", ""),
        "bind_dn": kv.get("LDAP_BIND_DN", ""),
        "bind_password": kv.get("LDAP_BIND_PASSWORD", ""),
        "user_attribute": kv.get("LDAP_USER_ATTRIBUTE") or ("uid" if schema == "rfc2307" else "sAMAccountName"),
        "group": kv.get("LDAP_GROUP", "").strip(),
    }


def _server(conn):
    import ssl
    tls = None
    if conn["use_ssl"]:
        # match how Open WebUI itself binds (PROTOCOL_TLS, validate from the
        # certificate-check toggle); no hostname pinning so an internal CA whose
        # certificate CN differs from the host still works when verify is on.
        validate = ssl.CERT_REQUIRED if conn["tls_verify"] else ssl.CERT_NONE
        tls = ldap3.Tls(validate=validate, version=ssl.PROTOCOL_TLS)
    return ldap3.Server(conn["host"], port=conn["port"], use_ssl=conn["use_ssl"], tls=tls, connect_timeout=TIMEOUT)


def _group_filter(conn):
    """Turn the configured group into an Open WebUI LDAP_SEARCH_FILTER.

    AD/Samba matches nested membership (LDAP_MATCHING_RULE_IN_CHAIN); rfc2307
    uses a plain memberOf (needs the memberof overlay on the server). An
    unresolvable group fails closed.
    """
    group = conn["group"]
    if not group:
        return ""
    group_dn = group if "=" in group else None
    if group_dn is None:
        try:
            with ldap3.Connection(_server(conn), conn["bind_dn"], conn["bind_password"], receive_timeout=TIMEOUT) as c:
                if not c.bind():
                    _log(agent.SD_WARNING + "group lookup: the service account bind failed; logins are refused")
                    return _FAIL_CLOSED_FILTER
                name = escape_filter_chars(group)
                if conn["schema"] == "ad":
                    gfilter = f"(&(objectClass=group)(sAMAccountName={name}))"
                else:
                    gfilter = f"(&(objectClass=posixGroup)(cn={name}))"
                c.search(conn["base_dn"], gfilter, attributes=[])
                if len(c.entries) != 1:
                    _log(agent.SD_WARNING + f"group {group!r} not found in the directory; logins are refused")
                    return _FAIL_CLOSED_FILTER
                group_dn = c.entries[0].entry_dn
        except ldap3.core.exceptions.LDAPException as exc:
            _log(agent.SD_WARNING + f"group lookup failed ({type(exc).__name__}); logins are refused")
            return _FAIL_CLOSED_FILTER
    escaped_dn = escape_filter_chars(group_dn)
    if conn["schema"] == "ad":
        return f"(memberOf:1.2.840.113556.1.4.1941:={escaped_dn})"
    return f"(memberOf={escaped_dn})"


def native_env_lines():
    """The Open WebUI native LDAP_* lines for state/ldap.env.

    Carries LDAP_APP_PASSWORD, so the caller writes them to a 0600 file. When
    the login is off or the directory is unavailable the directory is disabled
    (ENABLE_LDAP=false) rather than left half-configured.
    """
    if not _enabled():
        return ["ENABLE_LDAP=false"]
    conn = _resolved_connection()
    if not conn:
        return ["ENABLE_LDAP=false"]

    label = os.environ.get("LDAP_LABEL", "AD / LDAP").strip() or "AD / LDAP"
    mail_attribute = os.environ.get("LDAP_MAIL_ATTRIBUTE", "mail").strip() or "mail"

    # a group restriction set by hand on an older version is preserved verbatim
    # (update-module.d/04migrate_ldap moves the former free-text filter here);
    # the group selector of the settings page takes over once it is used.
    raw_filter = os.environ.get("LDAP_RAW_SEARCH_FILTER", "").strip()
    search_filter = _group_filter(conn) if conn["group"] else raw_filter

    # LDAP_VALIDATE_CERT only has a meaning for a TLS connection; the proxy on
    # the node loopback and plain ldap:// are not checked.
    validate_cert = "true" if (conn["use_ssl"] and conn["tls_verify"]) else "false"

    return [
        "ENABLE_LDAP=true",
        f"LDAP_SERVER_LABEL={label}",
        f"LDAP_SERVER_HOST={conn['host']}",
        f"LDAP_SERVER_PORT={conn['port']}",
        f"LDAP_ATTRIBUTE_FOR_USERNAME={conn['user_attribute']}",
        f"LDAP_ATTRIBUTE_FOR_MAIL={mail_attribute}",
        f"LDAP_APP_DN={conn['bind_dn']}",
        f"LDAP_APP_PASSWORD={conn['bind_password']}",
        f"LDAP_SEARCH_BASE={conn['base_dn']}",
        f"LDAP_SEARCH_FILTER={search_filter}",
        f"LDAP_USE_TLS={'true' if conn['use_ssl'] else 'false'}",
        f"LDAP_VALIDATE_CERT={validate_cert}",
        "LDAP_CIPHERS=ALL",
    ]


def write_env_file(path="ldap.env"):
    header = "# Generated by bin/discover-ldap from the module settings. Do not edit by hand."
    old_umask = os.umask(0o077)
    try:
        with open(path + ".tmp", "w") as fp:
            fp.write("\n".join([header] + native_env_lines()) + "\n")
        os.replace(path + ".tmp", path)
    finally:
        os.umask(old_umask)
