# Implementation Plan: Paste Image Documentation

## Overview

This plan implements clipboard image paste capability for the DokumentasiFormSheet widget. The implementation follows the existing project architecture (Riverpod, layered structure) and introduces three new components: ClipboardService (with platform implementations), ImageCompressor, and PasteImageHandler widget. Tasks are ordered to build foundational services first, then the UI integration layer, and finally wiring everything together.

## Tasks

- [x] 1. Set up core data models and service interfaces
  - [x] 1.1 Create ClipboardReadResult sealed class and ClipboardService abstract class
    - Create `lib/core/services/clipboard_service.dart`
    - Define `ClipboardReadResult` sealed class with variants: `ClipboardImageSuccess`, `ClipboardEmpty`, `ClipboardNoImage`, `ClipboardCorruptImage`, `ClipboardPermissionDenied`, `ClipboardUnsupported`
    - Define `ClipboardService` abstract class with `readImageFromClipboard()` and `isSupported` getter
    - _Requirements: 1.2, 1.4, 5.1, 5.2, 5.3, 5.4_

  - [x] 1.2 Create CompressResult sealed class and ImageCompressor class
    - Create `lib/core/services/image_compressor.dart`
    - Define `CompressResult` sealed class with variants: `CompressSuccess`, `CompressTooLarge`, `CompressError`
    - Implement `ImageCompressor` with constants: `maxDimension=1920`, `maxSizeBytes=5MB`, `startQuality=80`, `minQuality=40`, `qualityStep=10`
    - Implement `compress(Uint8List imageBytes)` method using `dart:ui` codec for decode/encode
    - Handle resize maintaining aspect ratio, alpha channel replacement with white background, progressive quality reduction loop
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 1.3 Create ImageSourceType enum
    - Create `lib/features/dokumentasi/domain/image_source_type.dart`
    - Define enum with values: `camera`, `gallery`, `paste`
    - _Requirements: 4.2, 6.2_

- [x] 2. Implement platform-specific clipboard services
  - [x] 2.1 Implement WebClipboardService
    - Create `lib/core/services/web_clipboard_service.dart`
    - Use `dart:js_interop` to access browser `navigator.clipboard.read()` API
    - Check for ClipboardItem API support in `isSupported` getter
    - Iterate clipboard items for image/\* MIME types (image/png, image/jpeg, image/webp)
    - Read blob as Uint8List and validate image can be decoded
    - Implement 5-second timeout on clipboard read operations
    - Return appropriate `ClipboardReadResult` variant for each outcome
    - _Requirements: 2.4, 2.5, 2.3, 1.1_

  - [x] 2.2 Implement NativeClipboardService
    - Create `lib/core/services/native_clipboard_service.dart`
    - Use MethodChannel for platform-specific image clipboard access on mobile
    - Set `isSupported` to return true (always show paste button on mobile)
    - Implement 5-second timeout on clipboard read operations
    - Return appropriate `ClipboardReadResult` variant for each outcome
    - _Requirements: 2.2, 2.3_

  - [x] 2.3 Create Riverpod providers for ClipboardService and ImageCompressor
    - Create `lib/core/services/clipboard_service_provider.dart`
    - Use `@riverpod` annotation to create `clipboardService` provider that returns `WebClipboardService` on web, `NativeClipboardService` otherwise
    - Create `imageCompressor` provider returning `ImageCompressor` instance
    - _Requirements: 2.3, 2.4_

- [x] 3. Implement PasteImageHandler widget
  - [x] 3.1 Create PasteImageHandler ConsumerStatefulWidget
    - Create `lib/features/dokumentasi/presentation/widgets/paste_image_handler.dart`
    - Accept `child`, `onImagePasted` (ValueChanged<Uint8List>), and optional `onError` callback
    - Wrap child with `Focus` widget for keyboard event handling
    - Inject `ClipboardService` and `ImageCompressor` via Riverpod ref
    - _Requirements: 7.1, 7.2, 7.3_

  - [x] 3.2 Implement focus-aware keyboard shortcut handling
    - Detect Ctrl+V (Cmd+V on macOS) key events in `_handleKeyEvent`
    - Implement `_isTextFieldFocused()` to check if primary focus is on EditableText
    - Return `KeyEventResult.ignored` for non-paste shortcuts (Ctrl+C, Ctrl+A, Ctrl+Z, Ctrl+X)
    - Return `KeyEventResult.ignored` when text field is focused (allow normal text paste)
    - Initiate clipboard read only when focus is NOT on text field
    - _Requirements: 6.6, 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 3.3 Implement paste execution flow in PasteImageHandler
    - Implement `_performPaste()` async method
    - Call `ClipboardService.readImageFromClipboard()`
    - On `ClipboardImageSuccess`: pass bytes to `ImageCompressor.compress()`
    - On `CompressSuccess`: call `onImagePasted` callback with compressed bytes
    - On any error result: show appropriate snackbar message with correct duration
    - Dismiss existing snackbar before showing new one (`hideCurrentSnackBar()`)
    - _Requirements: 1.1, 1.6, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

- [x] 4. Checkpoint - Ensure core services compile and pass basic tests
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Integrate paste feature into DokumentasiFormSheet
  - [x] 5.1 Add "Paste dari Clipboard" option to image picker bottom sheet
    - Modify existing `_showImagePicker()` in DokumentasiFormSheet
    - Add ListTile with `Icons.content_paste` icon and "Paste dari Clipboard" text
    - Dismiss bottom sheet before initiating clipboard read
    - Only show paste option when `ClipboardService.isSupported` is true
    - _Requirements: 6.1, 6.5, 2.5_

  - [x] 5.2 Add mobile paste button (Android/iOS)
    - Show dedicated "Paste dari Clipboard" button in image picker options on mobile platforms
    - Use `kIsWeb` and `Platform` checks to determine visibility
    - _Requirements: 2.2_

  - [x] 5.3 Wrap DokumentasiFormSheet content with PasteImageHandler
    - Wrap form content with `PasteImageHandler` on desktop/web platforms
    - Connect `onImagePasted` callback to update `_imageBytes` state
    - Track `_imageSourceType` to distinguish paste from camera/gallery
    - _Requirements: 2.1, 6.2, 7.1_

  - [x] 5.4 Implement image preview with clipboard badge overlay
    - Add clipboard icon badge at top-right corner of preview container when `_imageSourceType == ImageSourceType.paste`
    - Maintain existing 150px height, BoxFit.cover, 12px border radius, 2px primary-color border styling
    - Show success snackbar for 2 seconds on successful paste
    - _Requirements: 1.3, 1.6, 4.1, 4.2, 4.4_

  - [x] 5.5 Update image preview tap interaction
    - On tap of Image_Preview, show bottom sheet with options: "Ambil Foto", "Pilih dari Galeri", "Paste dari Clipboard", "Hapus Foto"
    - "Hapus Foto" resets `_imageBytes` to null and `_imageSourceType` to null
    - Ensure pasted image replaces existing image without confirmation dialog
    - _Requirements: 1.5, 4.3, 4.5_

  - [x] 5.6 Ensure pasted image uses same submission flow as camera/gallery
    - Verify pasted image stored in same `_imageBytes` state variable
    - Ensure form submission with pasted image uses identical upload mechanism
    - _Requirements: 6.2, 6.3, 6.4_

- [x] 6. Checkpoint - Ensure integration compiles and manual verification
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Write property-based tests
  - [x] 7.1 Write property test for valid image format acceptance
    - **Property 1: Valid image format acceptance**
    - **Validates: Requirements 1.2, 1.4**
    - Generate random byte arrays with valid PNG/JPEG/WEBP headers
    - Verify ClipboardService extracts bytes without data loss (input == output before compression)
    - Use `fast_check` with minimum 100 iterations
    - Create `test/features/dokumentasi/services/clipboard_service_test.dart`

  - [x] 7.2 Write property test for image replacement
    - **Property 2: Image replacement preserves only new image**
    - **Validates: Requirements 1.5, 6.2**
    - Generate pairs of random Uint8List (old image, new image)
    - Verify form state `_imageBytes` equals new image after paste
    - Use `fast_check` with minimum 100 iterations
    - Create `test/features/dokumentasi/presentation/dokumentasi_form_sheet_test.dart`

  - [x] 7.3 Write property test for resize aspect ratio preservation
    - **Property 3: Resize preserves aspect ratio within bounds**
    - **Validates: Requirements 3.1**
    - Generate random (width, height) pairs, some exceeding 1920
    - Verify output max(W', H') <= 1920 AND aspect ratio preserved within epsilon
    - Use `fast_check` with minimum 100 iterations
    - Create `test/features/dokumentasi/services/image_compressor_test.dart`

  - [x] 7.4 Write property test for alpha channel replacement
    - **Property 4: Alpha channel replacement produces opaque JPEG**
    - **Validates: Requirements 3.2**
    - Generate images with random alpha values
    - Verify output is JPEG with no alpha channel, transparent pixels rendered as white
    - Use `fast_check` with minimum 100 iterations
    - Add to `test/features/dokumentasi/services/image_compressor_test.dart`

  - [x] 7.5 Write property test for progressive quality reduction
    - **Property 5: Progressive quality reduction converges**
    - **Validates: Requirements 3.3, 3.4**
    - Generate large images that exceed 5MB at 80% quality
    - Verify qualities attempted in order [70, 60, 50, 40], stops at first <= 5MB
    - Verify `CompressTooLarge` returned if no quality produces <= 5MB
    - Use `fast_check` with minimum 100 iterations
    - Add to `test/features/dokumentasi/services/image_compressor_test.dart`

  - [x] 7.6 Write property test for error-to-message mapping
    - **Property 6: Error result to message mapping is total and deterministic**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4**
    - Generate all `ClipboardReadResult` error variants
    - Verify each variant maps to exactly one predetermined snackbar message
    - Use `fast_check` with minimum 100 iterations
    - Create `test/features/dokumentasi/presentation/paste_image_handler_test.dart`

  - [x] 7.7 Write property test for form state preservation on error
    - **Property 7: Form state preservation on error**
    - **Validates: Requirements 5.5**
    - Generate random form states + random error types
    - Verify form state is identical before and after error handling
    - Use `fast_check` with minimum 100 iterations
    - Add to `test/features/dokumentasi/presentation/dokumentasi_form_sheet_test.dart`

  - [x] 7.8 Write property test for focus-based paste routing
    - **Property 8: Focus-based paste routing**
    - **Validates: Requirements 6.6, 7.2, 7.3**
    - Generate (focus state, key event) pairs
    - Verify: text field focused → KeyEventResult.ignored; not focused → clipboard read initiated
    - Use `fast_check` with minimum 100 iterations
    - Add to `test/features/dokumentasi/presentation/paste_image_handler_test.dart`

  - [x] 7.9 Write property test for non-paste keyboard shortcuts
    - **Property 9: Non-paste keyboard shortcuts pass through**
    - **Validates: Requirements 7.1**
    - Generate random non-Ctrl+V key combinations
    - Verify PasteImageHandler returns KeyEventResult.ignored without state modification
    - Use `fast_check` with minimum 100 iterations
    - Add to `test/features/dokumentasi/presentation/paste_image_handler_test.dart`

  - [x] 7.10 Write property test for image priority in mixed clipboard
    - **Property 10: Image priority in mixed clipboard content**
    - **Validates: Requirements 7.5**
    - Generate mixed clipboard states (text + image)
    - Verify image data is extracted when focus is not on text field
    - Use `fast_check` with minimum 100 iterations
    - Add to `test/features/dokumentasi/services/clipboard_service_test.dart`

- [x] 8. Write unit tests
  - [x] 8.1 Write unit tests for DokumentasiFormSheet paste integration
    - Test snackbar appears on successful paste (Req 1.6)
    - Test paste button shown on mobile (Req 2.2)
    - Test paste option hidden when unsupported (Req 2.5)
    - Test clipboard badge shown on pasted image (Req 4.2)
    - Test bottom sheet shows all options after paste (Req 4.3)
    - Test "Hapus Foto" resets to empty state (Req 4.5)
    - Test snackbar dismissed on new error (Req 5.7)
    - Test bottom sheet dismissed before clipboard read (Req 6.5)
    - Add to `test/features/dokumentasi/presentation/dokumentasi_form_sheet_test.dart`

  - [x] 8.2 Write unit tests for PasteImageHandler keyboard handling
    - Test keyboard listener registered on desktop/web (Req 2.1)
    - Test no error shown for text-only clipboard on non-text focus (Req 7.4)
    - Add to `test/features/dokumentasi/presentation/paste_image_handler_test.dart`

  - [x] 8.3 Write integration test for full paste flow
    - Test full paste → compress → preview → submit flow (Req 6.3, 6.4)
    - Test clipboard timeout at 5 seconds (Req 2.3)
    - Test compression completes within 10 seconds (Req 3.5)
    - Create `test/integration/paste_image_flow_test.dart`

- [x] 9. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties using `fast_check` Dart package
- Unit tests validate specific examples and edge cases
- The design specifies no new dependencies — uses `dart:ui` for image codec and existing `http` package
- Platform detection uses `kIsWeb` and `dart:io` `Platform` class
- All error snackbars preserve form state completely

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.3"] },
    { "id": 1, "tasks": ["1.2", "2.1", "2.2"] },
    { "id": 2, "tasks": ["2.3"] },
    { "id": 3, "tasks": ["3.1"] },
    { "id": 4, "tasks": ["3.2", "3.3"] },
    { "id": 5, "tasks": ["5.1", "5.2", "5.3"] },
    { "id": 6, "tasks": ["5.4", "5.5", "5.6"] },
    { "id": 7, "tasks": ["7.1", "7.3", "7.6", "7.8", "7.9", "7.10"] },
    { "id": 8, "tasks": ["7.2", "7.4", "7.5", "7.7", "8.1", "8.2"] },
    { "id": 9, "tasks": ["8.3"] }
  ]
}
```
