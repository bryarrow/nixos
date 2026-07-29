{ lib
, stdenv
, fetchFromGitHub
, meson
, ninja
, pkg-config
, gobject-introspection
, glib
, mutter
, bc
, cairo
, gsettings-desktop-schemas
, wayland
, libglvnd
, libx11
, libxfixes
, libxi
, atk
, libxkbcommon
, lcms2
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gnome-rounded-blur";
  version = "1.0.0-unstable-2026-04-08";

  src = fetchFromGitHub {
    owner = "kancko";
    repo = "gnome-rounded-blur";
    rev = "9c7efb7ac5de60fee47ae403753e54319e839f03";
    hash = "sha256-hiWQaYydlyIMHKsx49f7sGOLM9ev1g1kdlloUszZU8I=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    gobject-introspection
    bc
  ];

  buildInputs = [
    atk
    cairo
    glib
    gsettings-desktop-schemas
    lcms2
    libglvnd
    libxkbcommon
    mutter
    wayland
    libx11
    libxfixes
    libxi
  ];

  postPatch = ''
    bash ${./scripts/apply-upstream-mutter-version-logic.sh} \
      "${mutter.version}" \
      "${mutter.passthru.libmutter_api_version}"
  '';

  meta = {
    description = "供 Blur my Shell 使用的圆角模糊 GObject introspection 库";
    homepage = "https://github.com/kancko/gnome-rounded-blur";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
})
