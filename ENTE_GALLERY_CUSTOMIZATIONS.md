# Ente Gallery customizations

This checkout tracks `ente/ente` through the `upstream` remote and uses the user's fork as `origin`. Custom app changes are on `codex/ente-gallery-customizations` so upstream updates can be merged or rebased without replacing the upstream `main` branch.

## App identity

The Android package ID is `io.ente.gallery` before the selected build flavor suffix. The `independent` flavor therefore installs as `io.ente.gallery.independent`, separate from the official Ente Photos app. The launcher alias named `IconGreen` uses the supplied Ente Gallery icon; Ente's alternate icon choices remain available.

## Features

- **Keep thumbnails offline:** encrypted remote thumbnail responses are decrypted as in the stock app, then copied to an app-private persistent thumbnail directory. Normal thumbnail reads prefer this directory. The operation only calls the thumbnail endpoint; it does not download originals. The persistent directory is under Documents, which Ente already excludes from device backups. The job is sequential and can be resumed by starting it again; files already present are skipped. The storage cap defaults to 4 GiB and can be raised to 16 GiB. Full-resolution viewing still needs the original-file download path and network access.
- **Album groups:** group metadata is stored locally in SharedPreferences and contains only album IDs. The Ente server collection model remains unchanged. Groups are device-local and do not sync to other devices.
- **Favorites tab:** opens the account's existing Favorites collection. Its collection IDs and membership continue to sync through Ente.

## Updating from Ente

Fetch upstream changes and merge or rebase `upstream/main` into `codex/ente-gallery-customizations`. Review conflicts in the small integration points (`home_widget.dart`, `home_bottom_nav_bar.dart`, `albums_tab.dart`, `thumbnail.dart`, `configuration.dart`, and `settings_page.dart`) against upstream before building. Keep feature-specific storage and screens in their dedicated service/UI files.
