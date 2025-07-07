{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.keycloak;

  inherit (lib)
    mkIf
    mkMerge
    mkOption
    mkPackageOption
    types
    ;

  inherit (types)
    nullOr
    oneOf
    listOf
    attrsOf
    ;
in
{
  options.services.keycloak = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether to enable the Keycloak identity and access management
        server.
      '';
    };

    sslCertificate = mkOption {
      type = nullOr (
        lib.types.pathWith {
          inStore = false;
          absolute = false;
        }
      );
      default = null;
      example = "/run/keys/ssl_cert";
      description = ''
        The path to a PEM formatted certificate to use for TLS/SSL
        connections.
      '';
    };

    sslCertificateKey = mkOption {
      type = nullOr (
        lib.types.pathWith {
          inStore = false;
          absolute = false;
        }
      );
      default = null;
      example = "/run/keys/ssl_key";
      description = ''
        The path to a PEM formatted private key to use for TLS/SSL
        connections.
      '';
    };

    plugins = mkOption {
      type = listOf types.path;
      default = [ ];
      description = ''
        Keycloak plugin jar, ear files or derivations containing
        them. Packaged plugins are available through
        `pkgs.keycloak.plugins`.
      '';
    };

    database = {
      type = mkOption {
        type = types.enum [
          "dev-mem"
          "dev-file"
        ];
        default = "dev-file";
        example = "dev-mem";
        description = ''
          The type of database Keycloak should connect to.
          If you use `dev-mem`, the realm export over script
          `keycloak-realm-export-*` does not work.
        '';
      };
    };

    package = mkPackageOption pkgs "keycloak" { };

    initialAdminPassword = mkOption {
      type = types.str;
      default = "admin";
      description = ''
        Initial password set for the temporary `admin` user.
        The password is not stored safely and should be changed
        immediately in the admin panel.

        See [Admin bootstrap and recovery](https://www.keycloak.org/server/bootstrap-admin-recovery) for details.
      '';
    };

    scripts = {
      exportRealm = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Global toggle to enable/disable the **single** realm export
          script `keycloak-realm-export`.
        '';
      };
    };

    processes = {
      exportRealms = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Global toggle to enable/disable the realms export process `keycloak-realm-export-all`
          if any realms have `realms.«name».export == true`.
        '';
      };
    };

    realms = mkOption {
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            path = mkOption {
              type = nullOr (
                lib.types.pathWith {
                  inStore = false;
                  absolute = false;
                }
              );
              default = null;
              example = "./realms/a.json";
              description = ''
                The path (string, relative to `DEVENV_ROOT`) where you want to import (or export) this realm «name» to.
                If not set and `import` is `true` this realm is not imported.
                If not set and `export` is `true` its exported to `$DEVENV_STATE/keycloak/realm-export/«name».json`.
              '';
            };

            import = mkOption {
              type = types.bool;
              default = true;
              example = true;
              description = ''
                If you want to import that realm on start up, if the realm does not yet exist.
              '';
            };

            export = mkOption {
              type = types.bool;
              default = false;
              example = true;
              description = ''
                If you want to export that realm on process/script launch `keycloak-export-realms`.
              '';
            };
          };
        }
      );

      example = lib.literalExpression ''
        {
          myrealm = {
            path = "./myfolder/export.json";
            import = true; # default
            export = true;
          };
        }
      '';

      description = ''
        Specify the realms you want to import on start up and
        export on a manual start of process/script 'keycloak-realm-export-all'.
      '';
    };

    settings = mkOption {
      type = lib.types.submodule {
        freeformType = attrsOf (
          nullOr (oneOf [
            types.str
            types.int
            types.bool
            (attrsOf types.path)
          ])
        );

        options = {
          http-host = mkOption {
            type = types.str;
            default = "::";
            example = "::1";
            description = ''
              On which address Keycloak should accept new connections.
            '';
          };

          http-port = mkOption {
            type = types.port;
            default = 8080;
            example = 8080;
            description = ''
              On which port Keycloak should listen for new HTTP connections.
            '';
          };

          https-port = mkOption {
            type = types.port;
            default = 34429;
            example = 34429;
            description = ''
              On which port Keycloak should listen for new HTTPS connections.
              If its not set, its disabled.
            '';
          };

          http-relative-path = mkOption {
            type = types.str;
            default = "/";
            example = "/auth";
            apply = x: if !(lib.hasPrefix "/") x then "/" + x else x;
            description = ''
              The path relative to `/` for serving
              resources.

              ::: {.note}
              In versions of Keycloak using Wildfly (&lt;17),
              this defaulted to `/auth`. If
              upgrading from the Wildfly version of Keycloak,
              i.e. a NixOS version before 22.05, you'll likely
              want to set this to `/auth` to
              keep compatibility with your clients.

              See <https://www.keycloak.org/migration/migrating-to-quarkus>
              for more information on migrating from Wildfly to Quarkus.
              :::
            '';
          };

          hostname = mkOption {
            type = types.str;
            default = "localhost";
            example = "localhost";
            description = ''
              The hostname part of the public URL used as base for
              all frontend requests.

              See <https://www.keycloak.org/server/hostname>
              for more information about hostname configuration.
            '';
          };
        };
      };

      example = lib.literalExpression ''
        {
          hostname = "localhost";
          https-key-store-file = "/path/to/file";
          https-key-store-password = { _secret = "/run/keys/store_password"; };
        }
      '';

      description = ''
        Configuration options corresponding to parameters set in
        {file}`conf/keycloak.conf`.

        Most available options are documented at <https://www.keycloak.org/server/all-config>.

        Options containing secret data should be set to an attribute
        set containing the attribute `_secret` - a
        string pointing to a file containing the value the option
        should be set to. See the example to get a better picture of
        this: in the resulting
        {file}`conf/keycloak.conf` file, the
        `https-key-store-password` key will be set
        to the contents of the
        {file}`/run/keys/store_password` file.
      '';
    };
  };

  config =
    let
      isSecret = v: lib.isAttrs v && v ? _secret && lib.isString v._secret;

      # Generate the keycloak config file to build it.
      keycloakConfig = lib.generators.toKeyValue {
        mkKeyValue = lib.flip lib.generators.mkKeyValueDefault "=" {
          mkValueString =
            v:
            if builtins.isInt v then
              toString v
            else if builtins.isString v then
              v
            else if true == v then
              "true"
            else if false == v then
              "false"
            else if isSecret v then
              builtins.hashString "sha256" v._secret
            else
              throw "unsupported type ${builtins.typeOf v}: ${(lib.generators.toPretty { }) v}";
        };
      };

      # Filters empty values out.
      filteredConfig = lib.converge (lib.filterAttrsRecursive (
        _: v:
        !builtins.elem v [
          { }
          null
        ]
      )) cfg.settings;

      # Write the keycloak config file.
      confFile = pkgs.writeText "keycloak.conf" (keycloakConfig filteredConfig);

      keycloakBuild = (
        cfg.package.override {
          inherit confFile;

          plugins = cfg.package.enabledPlugins ++ cfg.plugins;
        }
      );

      dummyCertificates = pkgs.stdenv.mkDerivation {
        pname = "dev-ssl-cert";
        version = "1.0";
        buildInputs = [ pkgs.openssl ];
        src = null;
        dontUnpack = true;
        buildPhase = ''
          mkdir -p $out
          openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout $out/ssl-cert.key -out $out/ssl-cert.crt \
            -days 365 \
            -subj "/CN=localhost"
        '';

        installPhase = "true";
      };

      providedSSLCerts = cfg.sslCertificate != null && cfg.sslCertificateKey != null;

      # Generate the command to import realms.
      realmImport = lib.mapAttrsToList (
        realm: e:
        let
          f = config.env.DEVENV_ROOT + "/" + e.path;
        in
        ''
          echo "Symlinking realm file '${f}' to import path '$KC_HOME_DIR/data/import'."
          if [ ! -f "${f}" ]; then
            echo "Realm file '${f}' does not exist!" >&2
            exit 1
          fi
          ln -fs "${f}" "$KC_HOME_DIR/data/import/"
        ''
      ) (lib.filterAttrs (_: v: v.import && v.path != null) cfg.realms);

      # Generate the commands to export realms.
      assertKeycloakStopped = [
        ''
          if ${keycloak-health}/bin/keycloak-health; then
            echo "You must first stop keycloak and then run this command again." >&2
            exit 1
          fi
        ''
      ];

      keycloak-realm-export = pkgs.writeShellScriptBin "keycloak-realm-export" (
        lib.concatStringsSep "\n" (
          assertKeycloakStopped
          ++ [
            ''
              ${keycloakBuild}/bin/kc.sh export --realm "$1" --file "$2"
            ''
          ]
        )
      );

      realmsToExport = lib.filterAttrs (_: v: v.export) cfg.realms;
      realmsExport =
        if (!cfg.processes.exportRealms || lib.length (lib.attrNames realmsToExport) == 0) then
          [ ]
        else
          assertKeycloakStopped
          ++ lib.mapAttrsToList (
            realm: e:
            let
              file =
                if e.path == null then
                  (config.env.DEVENV_STATE + "/keycloak/realm-export/${realm}.json")
                else
                  e.path;
            in
            ''
              echo "Exporting realm '${realm}' to '${file}'."
              mkdir -p "$(dirname "${file}")"
              ${keycloakBuild}/bin/kc.sh export --realm "${realm}" --file "${file}"

              echo "Beautifying realm export '${file}' for diffing."
              temp_file=$(${pkgs.coreutils}/bin/mktemp)
              ${pkgs.jq}/bin/jq --sort-keys . "${file}" > "$temp_file"
              ${pkgs.coreutils}/bin/mv "$temp_file" "${file}"
            ''
          ) realmsToExport;

      keycloak-realm-export-all = pkgs.writeShellScriptBin "keycloak-realm-export-all" (
        lib.concatStringsSep "\n" realmsExport
      );

      keycloak-health = pkgs.writeShellScriptBin "keycloak-health" ''
        ${pkgs.curl}/bin/curl -k --head -fsS "https://localhost:9000/health/ready"
      '';
    in
    mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.database.type == "dev-mem" -> realmsExport == [ ];
          message = ''
            You cannot export realms with `realms.«name».export == true` when
            using `database.type == 'dev-mem'`, import however works.
            You can disable realms export with `exportRealms = true` globally.
          '';
        }
      ];

      services.keycloak.settings = mkMerge [
        {
          # We always enable http since we also use it to check the health.
          http-enabled = true;
          db = cfg.database.type;

          health-enabled = true;

          log-console-level = "info";
          log-level = "info";

          https-certificate-file =
            if providedSSLCerts then cfg.sslCertificate else "${dummyCertificates}/ssl-cert.crt";
          https-certificate-key-file =
            if providedSSLCerts then cfg.sslCertificateKey else "${dummyCertificates}/ssl-cert.key";
        }
      ];

      packages = [ keycloakBuild ];

      env = {
        KC_HOME_DIR = config.env.DEVENV_STATE + "/keycloak";
        KC_CONF_DIR = config.env.DEVENV_STATE + "/keycloak/conf";
        KC_TMP_DIR = config.env.DEVENV_STATE + "/keycloak/tmp";

        KC_BOOTSTRAP_ADMIN_USERNAME = "admin";
        KC_BOOTSTRAP_ADMIN_PASSWORD = "${lib.escapeShellArg cfg.initialAdminPassword}";
      };

      processes.keycloak =
        let

          keycloak-start = pkgs.writeShellScriptBin "keycloak-start" ''
            set -euo pipefail
            mkdir -p "$KC_HOME_DIR"
            mkdir -p "$KC_HOME_DIR/conf"
            mkdir -p "$KC_HOME_DIR/tmp"

            # Always remove the symlinks for the realm imports.
            rm -rf "$KC_HOME_DIR/data/import" || true
            mkdir -p "$KC_HOME_DIR/data/import"

            ln -fs ${keycloakBuild}/providers "$KC_HOME_DIR/"
            ln -fs ${keycloakBuild}/lib "$KC_HOME_DIR/"
            install -D -m 0600 ${confFile} "$KC_HOME_DIR/conf/keycloak.conf"

            echo "Keycloak config:"
            ${keycloakBuild}/bin/kc.sh show-config || true

            echo "Import realms (if any)..."
            ${builtins.concatStringsSep "\n" realmImport}
            echo "========================"

            echo "Start keycloak:"
            ${keycloakBuild}/bin/kc.sh start --optimized --import-realm
          '';

        in
        {
          exec = "exec ${keycloak-start}/bin/keycloak-start";

          process-compose = {
            description = "The keycloak identity and access management server.";
            readiness_probe = {
              exec.command = "${keycloak-health}/bin/keycloak-health";
              initial_delay_seconds = 20;
              period_seconds = 10;
              timeout_seconds = 4;
              success_threshold = 1;
              failure_threshold = 20;
            };
          };
        };

      # Export a single realm.
      scripts.keycloak-realm-export = mkIf cfg.scripts.exportRealm {
        exec = "${keycloak-realm-export}/bin/keycloak-realm-export";
        description = ''
          Export a realm '$1' (first argument) from keycloak to location '$2' (second argument).
        '';
      };

      # Export all configured realms.
      scripts.keycloak-realm-export-all = mkIf (realmsExport != [ ]) {
        exec = "${keycloak-realm-export-all}/bin/keycloak-realm-export-all";
        description = ''
          Save the configured realms from keycloak, to back them up. You can run it manually.
        '';
      };

      # Process to start for exporting the above.
      processes.keycloak-realm-export-all = mkIf (realmsExport != [ ]) {
        exec = "${keycloak-realm-export-all}/bin/keycloak-realm-export-all";
        process-compose = {
          description = ''
            Save the configured realms from keycloak, to back them up. You can run it manually.
          '';
          disabled = true;
          depends_on = {
            keycloak = {
              condition = "process_completed";
            };
          };
        };
      };
    };
}
