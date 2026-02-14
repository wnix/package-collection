self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    mkDefault
    types
    ;

  cfg = config.services.seatsurfing;

  seatsurfing = self.packages.${pkgs.system};

  # Build the environment variables from cfg.settings
  envVars = lib.mapAttrs (_: toString) cfg.settings;
in
{
  options.services.seatsurfing = {
    enable = mkEnableOption "Seatsurfing desk booking service";

    package = mkOption {
      type = types.package;
      default = seatsurfing.server;
      defaultText = lib.literalExpression "seatsurfing.server";
      description = "The Seatsurfing server package to use.";
    };

    ui = {
      package = mkOption {
        type = types.package;
        default = seatsurfing.ui;
        defaultText = lib.literalExpression "seatsurfing.ui";
        description = "The Seatsurfing UI package to use.";
      };
    };

    user = mkOption {
      type = types.str;
      default = "seatsurfing";
      description = "User account under which Seatsurfing runs.";
    };

    group = mkOption {
      type = types.str;
      default = "seatsurfing";
      description = "Group under which Seatsurfing runs.";
    };

    settings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Environment variables for Seatsurfing configuration.
        Keys are the environment variable names as documented at
        https://seatsurfing.io/docs/self-hosted/config/.

        Secrets (POSTGRES_URL, CRYPT_KEY, SMTP_AUTH_PASS, INIT_ORG_PASS, ...)
        should NOT be placed here -- use `environmentFiles` instead so they
        don't end up in the world-readable Nix store.
      '';
      example = lib.literalExpression ''
        {
          PUBLIC_SCHEME = "https";
          PUBLIC_PORT = "443";
          INIT_ORG_NAME = "My Company";
          SMTP_HOST = "smtp.example.com";
          SMTP_PORT = "587";
          SMTP_START_TLS = "1";
          SMTP_AUTH = "1";
        }
      '';
    };

    environmentFiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of paths to environment files containing secrets.
        Each file should contain lines of the form `KEY=VALUE`.

        Use this for sensitive values such as POSTGRES_URL, CRYPT_KEY,
        SMTP_AUTH_PASS, INIT_ORG_PASS, or VALKEY_PASSWORD.
      '';
      example = lib.literalExpression ''
        [ config.sops.secrets."seatsurfing-env".path ]
      '';
    };
  };

  config = mkIf cfg.enable {

    services.seatsurfing.settings = {
      # -- Paths (derived from packages) --
      STATIC_UI_PATH = mkDefault "${cfg.ui.package}";
      FILESYSTEM_BASE_PATH = mkDefault "${cfg.package}/share/seatsurfing";

      # -- Network / reverse proxy --
      PUBLIC_LISTEN_ADDR = mkDefault "127.0.0.1:8080";
      PUBLIC_SCHEME = mkDefault "https";
      PUBLIC_PORT = mkDefault "443";

      # -- Initial organization --
      INIT_ORG_NAME = mkDefault "Sample Company";
      INIT_ORG_USER = mkDefault "admin";
      INIT_ORG_LANGUAGE = mkDefault "en";

      # -- Mail / SMTP --
      MAIL_SERVICE = mkDefault "smtp";
      MAIL_SENDER_ADDRESS = mkDefault "no-reply@seatsurfing.local";
      SMTP_HOST = mkDefault "127.0.0.1";
      SMTP_PORT = mkDefault "25";
      SMTP_START_TLS = mkDefault "0";
      SMTP_AUTH = mkDefault "0";
      SMTP_AUTH_METHOD = mkDefault "PLAIN";

      # -- Login protection --
      LOGIN_PROTECTION_MAX_FAILS = mkDefault "10";
      LOGIN_PROTECTION_SLIDING_WINDOW_SECONDS = mkDefault "600";
      LOGIN_PROTECTION_BAN_MINUTES = mkDefault "5";

      # -- Rate limiting --
      RATE_LIMIT = mkDefault "250";
      RATE_LIMIT_PERIOD = mkDefault "1-M";

      # -- Feature flags --
      DISABLE_PASSWORD_LOGIN = mkDefault "0";
      ALLOW_ORG_DELETE = mkDefault "0";

      # -- Cache --
      CACHE_TYPE = mkDefault "default";
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "Seatsurfing service user";
    };

    users.groups.${cfg.group} = { };

    systemd.services.seatsurfing = {
      description = "Seatsurfing Desk Booking Server";
      documentation = [ "https://seatsurfing.io/docs/" ];
      after = [
        "network.target"
        "postgresql.service"
      ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = envVars;

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/server";
        WorkingDirectory = "${cfg.package}/share/seatsurfing";
        Restart = "on-failure";
        RestartSec = 5;

        User = cfg.user;
        Group = cfg.group;

        EnvironmentFile = cfg.environmentFiles;

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
        MemoryDenyWriteExecute = true;
        UMask = "0077";
      };
    };
  };
}
