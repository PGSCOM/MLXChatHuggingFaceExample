# MLXChatHuggingFace

Fork de [`ml-explore/mlx-swift-examples`](https://github.com/ml-explore/mlx-swift-examples) que
añade a **MLXChatExample** un catálogo de modelos libre: además de los presets del ejemplo
original, puedes pegar el repo de Hugging Face que quieras (`org/modelo` o una URL) y la app lo
añade a la lista.

## Qué cambia respecto a upstream

- `Applications/MLXChatExample/Models/CustomModelStore.swift` (nuevo): valida el repo contra la
  API de Hugging Face, detecta si es LLM o VLM (o fuerzas el tipo a mano) y persiste la lista en
  `UserDefaults`.
- `Applications/MLXChatExample/Views/Toolbar/AddModelView.swift` (nuevo): hoja para añadir/borrar
  modelos.
- `ViewModels/ChatViewModel.swift` y `Views/Toolbar/ChatToolbarView.swift`: cambios mínimos para
  enchufar el catálogo libre junto a los presets.
- `.github/workflows/unsigned-ipa.yml` (nuevo): compila un `.ipa` **sin firmar** de
  MLXChatExample para iOS.

Todo lo demás es el repo de Apple tal cual. Los merges de `upstream/main` deberían seguir siendo
triviales.

## Actualizar desde upstream

```bash
git fetch upstream
git merge upstream/main
```

## Generar el .ipa

Actions → **Build unsigned MLXChatExample .ipa** → Run workflow. O crea un tag `v*`
(`git tag v1.0 && git push origin v1.0`) para que además suba el `.ipa` como asset de un Release.

El `.ipa` **no está firmado**: instálalo con [Sideloadly](https://sideloadly.io/) o
[AltStore](https://altstore.io/), que lo re-firman con tu Apple ID gratuito al instalarlo (válido
7 días, hay que reinstalar).

## Limitaciones

- Solo repos públicos de Hugging Face (sin token, sin modelos *gated*).
- MLX Swift no lee GGUF: el repo debe traer pesos en `.safetensors` (los de
  [`mlx-community`](https://huggingface.co/mlx-community) valen).
- Sin gestión de descargas (progreso por modelo, borrar pesos, avisar si no cabe en RAM) ni
  persistencia de conversaciones.
