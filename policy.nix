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

  ExtensionSettings = lib.mapAttrs (_: install_url: {
    installation_mode = "normal_installed";
    inherit install_url;
  }) (optionalAttrs firefox {
    "uBlock0@raymondhill.net" = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
    "@testpilot-containers" = "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi";
    "gdpr@cavi.au.dk" = "https://addons.mozilla.org/firefox/downloads/latest/consent-o-matic/latest.xpi";
    "jid1-BoFifL9Vbdl2zQ@jetpack" = "https://addons.mozilla.org/firefox/downloads/latest/decentraleyes/latest.xpi";
    "FirefoxColor@mozilla.com" = "https://addons.mozilla.org/firefox/downloads/latest/firefox-color/latest.xpi";
  } // optionalAttrs thunderbird {
    "dkim_verifier@pl" = "https://addons.thunderbird.net/thunderbird/downloads/latest/dkim-verifier/latest.xpi";
  });

  FirefoxHome = {
    Pocket = false;
    SponsoredTopSites = false;
    SponsoredPocket = false;
  };

  FirefoxSuggest = {
    SponsoredSuggestions = false;
    ImproveSuggest = false;
  };

  GenerativeAI.Enabled = false;
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
    "intl.date_time.pattern_override.connector_short" = default "{1}' '{0}";  # en space
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

    # prevent access to Tor hidden services
    "network.dns.blockDotOnion" = locked true;

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
  } // optionalAttrs thunderbird {
    # disable audible notifications
    "calendar.alarms.playsound" = default false;
    "mail.biff.play_sound" = default false;

    # calendar week starts on Monday
    "calendar.week.start" = default 1;

    # always display e‐mail addresses
    "mail.addressDisplayFormat" = default 0;
    "mail.showCondensedAddresses" = default false;

    # disable chat component
    "mail.chat_enabled" = default false;

    # separate attachments from message body
    "mail.content_disposition_type" = default 1;

    # enable plain text highlighting
    "mail.display_struct" = default true;

    # force plain‐text composition
    "mail.html_compose" = locked false;
    "mail.identity.default.compose_html" = locked false;

    # reply on bottom
    "mail.identity.default.reply_on_top" = default false;

    # QoS: AF13
    "mail.imap.qos" = default 56;
    "mail.smtp.qos" = default 56;

    # avoid STARTTLS
    "mail.server.default.port" = locked 993;
    "mail.server.default.socketType" = locked 3;
    "mail.smtpserver.default.port" = locked 465;
    "mail.smtpserver.default.try_ssl" = locked 3;

    # flowed message support
    "mailnews.display.disable_format_flowed_support" = default false;
    "mailnews.send_plaintext_flowed" = default true;
    "plain_text.wrap_long_lines" = default true;

    # default message display
    "mailnews.default_sort_order" = default 1;  # ascending
    "mailnews.default_sort_type" = default 18;  # by date
    "mailnews.default_view_flags" = default 1;  # threaded

    # sanitise HTML
    "mailnews.display.html_as" = default 3;

    # display sender’s timezone
    "mailnews.display.date_senders_timezone" = default true;

    # force reduced user agent
    "mailnews.headers.useMinimalUserAgent" = locked true;

    # search by ISO 8601 date
    "mailnews.search_date_format" = default 1;
    "mailnews.search_date_separator" = default "-";

    # force UTF-8 encoding
    "mailnews.send_default_charset" = locked "UTF-8";
    "mailnews.reply_in_default_charset" = locked true;
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
