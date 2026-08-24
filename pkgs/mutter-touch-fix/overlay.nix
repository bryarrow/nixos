final: prev:

{
  mutter = prev.mutter.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ./fix-null-focus-surface.patch
    ];
  });
}
