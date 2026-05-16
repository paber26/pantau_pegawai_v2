/// Identifies how an image was added to the documentation form.
///
/// Used by `DokumentasiFormSheet` to distinguish between images attached via
/// camera, gallery, or clipboard paste — for example, to show a clipboard
/// badge overlay on the image preview when the source is [paste].
enum ImageSourceType {
  /// Image captured via the device camera.
  camera,

  /// Image selected from the device gallery.
  gallery,

  /// Image pasted from the system clipboard.
  paste,
}
