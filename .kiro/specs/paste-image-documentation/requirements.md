# Requirements Document

## Introduction

This feature adds clipboard image paste capability to the documentation form in the Pantau Pegawai V2 Flutter application. Currently, users can only attach images by taking a photo with the camera or selecting from the gallery. This enhancement allows users to copy a screenshot or image to their clipboard and paste it directly into the documentation form, significantly speeding up the documentation workflow — especially on desktop/web platforms where screenshots are frequently used.

## Glossary

- **Paste_Image_Handler**: The component responsible for detecting clipboard content, extracting image data, and providing it to the documentation form
- **Documentation_Form**: The existing `DokumentasiFormSheet` widget where users create documentation entries with optional image attachments
- **Clipboard_Service**: The platform-specific service that reads image data from the system clipboard
- **Image_Preview**: The widget area within the Documentation_Form that displays the selected or pasted image before submission
- **Image_Compressor**: The component responsible for resizing and compressing pasted images to meet size constraints

## Requirements

### Requirement 1: Paste Image from Clipboard

**User Story:** As an employee, I want to paste an image from my clipboard into the documentation form, so that I can quickly attach screenshots without switching to the gallery or camera.

#### Acceptance Criteria

1. WHEN the user triggers a paste action (Ctrl+V on desktop/web, or taps a paste button on mobile), THE Paste_Image_Handler SHALL read image data from the system clipboard within 2 seconds
2. WHEN the clipboard contains image data that is in PNG, JPEG, or WEBP format and can be successfully decoded into pixel data, THE Paste_Image_Handler SHALL extract the image bytes and pass them to the Documentation_Form
3. WHEN a pasted image is received by the Documentation_Form, THE Image_Preview SHALL display the pasted image in the existing 150px height preview container within 500 milliseconds of receiving the image bytes
4. THE Paste_Image_Handler SHALL support PNG, JPEG, and WEBP image formats from the clipboard
5. WHEN the user pastes an image while an existing image is already selected, THE Documentation_Form SHALL replace the existing image with the newly pasted image without displaying a confirmation dialog
6. WHEN an image is successfully pasted and displayed in the Image_Preview, THE Documentation_Form SHALL show a brief visual confirmation (snackbar) indicating the image was pasted successfully, displayed for 2 seconds

### Requirement 2: Platform-Specific Paste Behavior

**User Story:** As an employee using the app on different platforms, I want clipboard paste to work appropriately on each platform, so that I have a consistent experience regardless of device.

#### Acceptance Criteria

1. WHILE the app is running on web or desktop (macOS, Windows, Linux), THE Paste_Image_Handler SHALL listen for keyboard shortcut Ctrl+V (or Cmd+V on macOS) to trigger paste
2. WHILE the app is running on mobile (Android, iOS), THE Documentation_Form SHALL display a dedicated "Paste dari Clipboard" button in the image picker options
3. WHEN the paste action is triggered on any platform, THE Clipboard_Service SHALL use the platform-appropriate API to access clipboard image data with a timeout of 5 seconds
4. WHILE the app is running on web, THE Paste_Image_Handler SHALL use the browser Clipboard API to read image data
5. IF the browser does not support the Clipboard API (e.g., older browsers without navigator.clipboard.read), THEN THE Documentation_Form SHALL hide the paste option and not register keyboard shortcut listeners for paste

### Requirement 3: Image Compression and Size Handling

**User Story:** As an employee, I want pasted images to be automatically optimized, so that uploads are fast and storage is used efficiently.

#### Acceptance Criteria

1. WHEN a pasted image exceeds 1920 pixels in width or height, THE Image_Compressor SHALL resize the image to fit within 1920x1920 pixels while maintaining the aspect ratio
2. WHEN a pasted image is processed, THE Image_Compressor SHALL compress the image to JPEG format with 80% quality, replacing any alpha channel (transparency) with a white background
3. WHEN the compressed image exceeds 5 MB in size, THE Image_Compressor SHALL reduce quality in decrements of 10% (from 80% down to a minimum of 40%) until the image is under 5 MB or the minimum quality threshold is reached
4. IF the image cannot be compressed below 5 MB at minimum quality (40%), THEN THE Documentation_Form SHALL display an error message indicating the image is too large and SHALL discard the pasted image, preserving any previously selected image
5. WHEN the Image_Compressor successfully compresses a pasted image, THE Image_Compressor SHALL produce the final image within 10 seconds on the target device

### Requirement 4: Image Preview and Interaction

**User Story:** As an employee, I want to see a preview of the pasted image before submitting, so that I can verify the correct image was pasted.

#### Acceptance Criteria

1. WHEN an image is pasted successfully, THE Image_Preview SHALL display the image within the existing 150px height preview container using BoxFit.cover scaling and a 12px border radius
2. WHEN a pasted image is displayed in the Image_Preview, THE Documentation_Form SHALL show a clipboard icon badge positioned at the top-right corner of the preview container to indicate the image was added via paste
3. WHEN the user taps the Image_Preview area after pasting, THE Documentation_Form SHALL present a bottom sheet with options: "Ambil Foto" (camera), "Pilih dari Galeri" (gallery), "Paste dari Clipboard" (paste), and "Hapus Foto" (remove)
4. THE Image_Preview SHALL render the pasted image with the same container styling as camera/gallery-selected images, including a 2px primary-color border and 12px rounded corners
5. WHEN the user selects "Hapus Foto" from the Image_Preview options, THE Documentation_Form SHALL remove the pasted image and return the preview container to its empty placeholder state

### Requirement 5: Error Handling for Invalid Clipboard Content

**User Story:** As an employee, I want clear feedback when paste fails, so that I understand what went wrong and can take corrective action.

#### Acceptance Criteria

1. IF the clipboard is empty when paste is triggered, THEN THE Documentation_Form SHALL display a snackbar message "Clipboard kosong. Salin gambar terlebih dahulu." displayed for 3 seconds
2. IF the clipboard contains text or non-image data when paste is triggered, THEN THE Documentation_Form SHALL display a snackbar message "Clipboard tidak berisi gambar. Salin screenshot terlebih dahulu." displayed for 3 seconds
3. IF the clipboard image data is corrupted or cannot be decoded as a valid PNG, JPEG, or WEBP image, THEN THE Documentation_Form SHALL display a snackbar message "Gagal membaca gambar dari clipboard. Coba salin ulang." displayed for 3 seconds
4. IF clipboard access is denied by the platform (permission issue), THEN THE Documentation_Form SHALL display a snackbar message "Izin akses clipboard ditolak. Periksa pengaturan izin aplikasi." displayed for 4 seconds
5. WHEN an error occurs during paste, THE Documentation_Form SHALL preserve the entire current form state without modification, including any previously selected image, entered text in the catatan field, and selected documentation type
6. WHEN an error snackbar is dismissed or expires, THE Documentation_Form SHALL remain in its current state and allow the user to retry the paste action immediately without additional steps
7. IF a new paste error occurs while a previous error snackbar is still visible, THEN THE Documentation_Form SHALL dismiss the previous snackbar and display the new error snackbar

### Requirement 6: Integration with Existing Documentation Form

**User Story:** As an employee, I want the paste feature to work seamlessly with the existing documentation form workflow, so that my current habits are not disrupted.

#### Acceptance Criteria

1. THE Documentation_Form SHALL add a "Paste dari Clipboard" option in the existing image picker bottom sheet (alongside "Ambil Foto" and "Pilih dari Galeri")
2. WHEN an image is pasted, THE Documentation_Form SHALL store the image bytes in the same `_imageBytes` state variable used by camera and gallery selection
3. THE Documentation_Form SHALL allow the user to submit the form with a pasted image using the same submission flow as camera/gallery images
4. WHEN the form is submitted with a pasted image, THE Documentation_Form SHALL upload the image using the same upload mechanism as camera/gallery images
5. WHEN the user selects "Paste dari Clipboard" from the image picker bottom sheet, THE Documentation_Form SHALL dismiss the bottom sheet before initiating the clipboard read operation
6. WHEN Ctrl+V is pressed and the active focus is on a text input field (TextField or TextFormField widget), THE Paste_Image_Handler SHALL allow the default text paste behavior without intercepting the event

### Requirement 7: Keyboard Shortcut Handling on Desktop/Web

**User Story:** As an employee using the web or desktop app, I want to paste images using familiar keyboard shortcuts, so that the workflow feels natural and fast.

#### Acceptance Criteria

1. WHILE the Documentation_Form is open on web or desktop, THE Paste_Image_Handler SHALL listen for Ctrl+V (Cmd+V on macOS) keyboard events without consuming other keyboard shortcuts (Ctrl+C, Ctrl+A, Ctrl+Z, Ctrl+X)
2. WHEN Ctrl+V is pressed and the active focus is on a text input field (TextField or TextFormField widget), THE Paste_Image_Handler SHALL not intercept the event (allowing normal text paste)
3. WHEN Ctrl+V is pressed and the active focus is not on a text input field, THE Paste_Image_Handler SHALL read image data from the clipboard and pass any retrieved image bytes to the Documentation_Form for processing
4. IF Ctrl+V is pressed and the clipboard contains no image data (text-only, empty, or other non-image content), THEN THE Paste_Image_Handler SHALL allow the event to propagate without showing an error and without modifying the Documentation_Form state
5. WHEN Ctrl+V is pressed and the clipboard contains both text and image data, THE Paste_Image_Handler SHALL extract the image data and pass it to the Documentation_Form (prioritizing image over text when focus is not on a text input field)
