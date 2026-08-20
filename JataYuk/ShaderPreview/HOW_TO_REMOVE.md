# Shader Preview

Temporary AR object lab. Isolated from the rest of the app.

## Enable / disable

`ShaderPreviewGate.isEnabled` in `ShaderPreviewGate.swift` is `false`, so `ContentView` shows the real experiment.

Set it to `true` to get the object lab back.

## Delete

1. Revert the gate in `JataYuk/ContentView.swift` (restore `RootView(store: store)`).
2. Delete this folder: `JataYuk/ShaderPreview/`.

No Xcode project, scheme, or ShaderDev edits.

## Controls

- Prev / Next pages Monolith objects (`SM_Bottle_Food_Coloring_*`, dish soap, bowl, …).
- Drag to orbit (yaw + pitch). Objects are stood up from Z-up so labels face the camera.
- ShaderGraph is replaced with `PhysicallyBasedMaterial` before anything is added to the scene.
- Food-coloring / H2O2 / dish-soap labels load PNGs from `Labels/` (ShaderGraph textures are compiled away).
- Dish-soap liquid is `M_Water` tinted with `M_PET_DishSoap` green.
- Bowl is a porcelain-white PBR stand-in.
