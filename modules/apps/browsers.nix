{
  kanagawa,
  pkgs,
  ...
}:
{
  home-manager.users.abhay = {
    programs.firefox = {
      enable = true;
      package = pkgs.firefox-esr;
      profiles.abhay = {
        isDefault = true;

        settings = {
          "browser.startup.page" = 1;
          "browser.startup.homepage" = "about:home";
          "browser.newtabpage.enabled" = false;
          "browser.uidensity" = 1;
          "browser.compactmode.show" = true;
          "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
          "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
          "browser.newtabpage.activity-stream.feeds.system.topstories" = false;
          "browser.newtabpage.activity-stream.feeds.snippets" = false;
          "browser.newtabpage.activity-stream.feeds.telemetry" = false;
          "browser.newtabpage.activity-stream.showHighlights" = false;
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.discovery.enabled" = false;
          "extensions.pocket.enabled" = false;
          "browser.urlbar.suggest.searches" = false;
          "browser.urlbar.suggest.topsites" = false;
          "browser.urlbar.quicksuggest.enabled" = false;
          "browser.urlbar.quicksuggest.sponsored" = false;
          "signon.rememberSignons" = false;
          "datareporting.policy.dataSubmissionEnabled" = false;
          "datareporting.healthreport.uploadEnabled" = false;
          "toolkit.telemetry.enabled" = false;
          "toolkit.telemetry.unified" = false;
          "browser.ping-centre.telemetry" = false;
          "browser.newtabpage.activity-stream.telemetry" = false;
          "app.shield.optoutstudies.enabled" = false;
        };

        userChrome = ''
          :root {
            --kanagawa-blue: #${kanagawa.crystalBlue};
            --kanagawa-blue-bright: #${kanagawa.springBlue};
            --kanagawa-surface: #${kanagawa.sumiInk1};
            --kanagawa-surface-raised: #${kanagawa.sumiInk2};
            --kanagawa-text: #${kanagawa.fujiWhite};
          }

          #navigator-toolbox,
          #TabsToolbar,
          #nav-bar {
            background: var(--kanagawa-surface) !important;
            color: var(--kanagawa-text) !important;
          }

          #urlbar-background,
          #searchbar {
            background: var(--kanagawa-surface-raised) !important;
            border: 1px solid var(--kanagawa-blue) !important;
          }

          .tab-background[selected="true"] {
            background: var(--kanagawa-surface-raised) !important;
            box-shadow: inset 0 2px var(--kanagawa-blue-bright) !important;
          }

          #nav-bar {
            border-top: 1px solid var(--kanagawa-blue) !important;
            min-height: 34px !important;
            padding-block: 2px !important;
          }

          #TabsToolbar {
            min-height: 30px !important;
          }

          .tabbrowser-tab {
            min-height: 30px !important;
            padding-inline: 4px !important;
          }

          #urlbar {
            min-height: 29px !important;
          }

          #home-button,
          #library-button,
          #sidebar-button,
          #save-to-pocket-button,
          #fxa-toolbar-menu-button {
            display: none !important;
          }
        '';

        search = {
          default = "ddg";
          privateDefault = "ddg";
          force = true;
          order = [
            "ddg"
            "google"
            "nixos-wiki"
            "github"
          ];
          engines = {
            ddg.metaData.alias = "@d";
            google.metaData.alias = "@g";
            bing.metaData.hidden = true;
            amazondotcom.metaData.hidden = true;
            ebay.metaData.hidden = true;
            wikipedia.metaData.hidden = true;
            nixos-wiki = {
              name = "NixOS Wiki";
              urls = [
                {
                  template = "https://wiki.nixos.org/w/index.php?search={searchTerms}";
                }
              ];
              definedAliases = [ "@nw" ];
            };
            github = {
              name = "GitHub";
              urls = [
                {
                  template = "https://github.com/search?q={searchTerms}&type=code";
                }
              ];
              definedAliases = [ "@gh" ];
            };
          };
        };
      };
      policies.ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
        };
        "{3e4d2037-d300-4e95-859d-3cba866f46d3}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/private-internet-access-ext/latest.xpi";
        };
      };
    };

  };
}
