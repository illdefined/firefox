{ lib, firefox ? false, thunderbird ? false }: let
  inherit (lib) optionals optionalAttrs;
in assert (lib.xor firefox thunderbird); {
  CaptivePortal = false;

  Cookies = {
    Behavior = "reject-tracker-and-partition-foreign";
    BehaviorPrivateBrowsing = "reject-tracker-and-partition-foreign";
  };

  DNSOverHTTPS.Enabled = false;
  DisableEncryptedClientHello = false;
  DisableFeedbackCommands = true;
  DisableFirefoxAccounts = true;
  DisableFirefoxStudies = true;
  DisablePocket = true;
  DisableSetDesktopBackground = true;
  DisableTelemetry = true;
  DontCheckDefaultBrowser = true;

  EnableTrackingProtection = {
    Value = true;
    Cryptomining = true;
    Fingerprinting = true;
    EmailTracking = true;
    SuspectedFingerprinting = true;
  };

  EncryptedMediaExtensions.Enabled = true;

  ExtensionSettings = {
    "uBlock0@raymondhill.net" = {
      installation_mode = "normal_installed";
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
    };
  } // optionalAttrs firefox {
    "@testpilot-containers" = {
      installation_mode = "normal_installed";
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi";
    };

    "gdpr@cavi.au.dk" = {
      installation_mode = "normal_installed";
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/consent-o-matic/latest.xpi";
    };

    "jid1-BoFifL9Vbdl2zQ@jetpack" = {
      installation_mode = "normal_installed";
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/decentraleyes/latest.xpi";
    };

    "FirefoxColor@mozilla.com" = {
      installation_mode = "normal_installed";
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/firefox-color/latest.xpi";
    };
  };

  FirefoxHome = {
    Pocket = false;
    SponsoredTopSites = false;
    SponsoredPocket = false;
  };

  FirefoxSuggest = {
    SponsoredSuggestions = false;
    ImproveSuggest = false;
  };

  GenerativeAI = {
    Chatbot = false;
    LinkPreviews = false;
    TabGroups = false;
  };

  HardwareAcceleration = true;
  Homepage.StartPage = "previous-session";
  HttpsOnlyMode = "force_enabled";
  NewTabPage = false;
  OfferToSaveLogins = false;
  OverrideFirstRunPage = "";
  PasswordManagerEnabled = false;

  PDFjs = {
    Enabled = true;
    EnablePermissions = false;
  };

  Permissions.AutoPlay.Default = "block-audio-video";
  PopupBlocking.Default = true;
  PostQuantumKeyAgreementEnabled = true;

  Preferences = let
    default = value: {
      Status = "default";
      Value = value;
    };

    locked = value: {
      Status = "locked";
      Value = value;
    };
  in {
    # use OS locale
    "intl.regional_prefs_us_os_locales" = true;

    # date and time formats
    "intl.date_time.pattern_override.date_short" = default "yyyy-MM-dd";
    "intl.date_time.pattern_override.time_short" = default "HH:mm";

    # cache
    "browser.cache.memory.enable" = default true;
    "browser.cache.memory.capacity" = default 262144;
    "browser.cache.disk.enable" = default true;
    "browser.cache.disk.capacity" = default 16777216;

    # disable WebGL by default
    "webgl.disabled" = default true;

    # disable Normandy
    "app.normandy.enabled" = locked false;
    "app.normandy.api_url" = locked "";
    "app.shield.optoutstudies.enabled" = locked false;

    # disable sending of file hashes
    "browser.safebrowsing.downloads.remote.enabled" = default false;
    "browser.safebrowsing.downloads.remote.url" = default "";

    # disable accessibility
    "accessibility.force_disabled" = default 1;

    # disable crash reporting
    "browser.tabs.crashReporting.sendReport" = locked false;
    "breakpad.reportURL" = locked "";

    # disable beacon API
    "beacon.enabled" = locked false;

    # disable pings
    "browser.send_pings" = locked false;

    # strip cross‐origin referrers
    "network.http.referrer.XOriginTrimmingPolicy" = default 2;

    # strip tracking query parameters
    "privacy.query_stripping.enabled" = default true;
    "privacy.query_stripping.enabled.pbmode" = default true;

    # disable CSP reporting
    "security.csp.reporting.enabled" = default false;

    # disable TLS error reporting to Mozilla
    "security.ssl.errorReporting.enabled" = default false;

    # TLS
    "security.insecure_connection_text.enabled" = default true;
    "security.insecure_connection_text.pbmode.enabled" = default true;
    "security.ssl.require_safe_negotiation" = default true;
    "security.tls.hello_downgrade_check" = default true;
    "security.cert_pinning.enforcement_level" = default 2;
    "security.pki.crlite_mode" = default 2;

    # enable ECN
    "network.http.http3.ecn" = default true;
  } // optionalAttrs firefox {
    # hardware acceleration
    "gfx.webrender.all" = default true;
    "gfx.webrender.compositor" = default true;
    "gfx.webrender.compositor.force-enabled" = default true;
    "layers.acceleration.force-enabled" = default true;
    "layers.gpu-process.enabled" = default true;
    "layers.gpu-process.force-enabled" = default true;
    "media.ffmpeg.vaapi.enabled" = default true;
    "media.gpu-process-decoder" = default true;

    # private container for new tab page thumbnails
    "privacy.usercontext.about_newtab_segregation.enabled" = default true;
  };

  PromptForDownloadLocation = true;
  RequestedLocales = [ "en-GB" ];
  ShowHomeButton = false;
  SSLVersionMin = "tls1.2";
  TranslateEnabled = true;

  UserMessaging = {
    ExtensionRecommendations = false;
    FeatureRecommendations = false;
    SkipOnboarding = false;
    MoreFromMozilla = false;
  };
}
