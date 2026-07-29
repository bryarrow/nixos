final: prev:

let
  gnome-rounded-blur = prev.callPackage ./package.nix { };
in
{
  inherit gnome-rounded-blur;

  gnome-shell = prev.gnome-shell.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
      prev.makeWrapper
    ];

    postFixup = (oldAttrs.postFixup or "") + ''
      wrapProgram "$out/bin/gnome-shell" \
        --prefix GI_TYPELIB_PATH : "${gnome-rounded-blur}/lib/girepository-1.0" \
        --prefix LD_LIBRARY_PATH : "${gnome-rounded-blur}/lib"
    '';

    passthru = (prev.gnome-shell.passthru or { }) // {
      inherit gnome-rounded-blur;
    };
  });
}
