# BeU Meal Photo Logging

## Architecture

- The iOS app handles image selection and camera capture.
- Both camera and gallery feed the same `selectedImage` state in the meal logging flow.
- The backend receives the image and performs meal analysis.
- The user must review and confirm detected items before logging.

## Camera behavior

- The app requests camera permission on first use.
- If the camera is unavailable, the app shows a friendly fallback message and the user can upload from the gallery instead.
- On iOS Simulator, camera capture is not supported. The app shows a note and uses gallery upload only.

## Shared analysis path

Camera and gallery use the same downstream flow:

1. Select image
2. Show preview
3. Analyze meal
4. Review detected items
5. Confirm/edit items
6. Show estimated nutrition
7. Select meal type
8. Log meal

## Notes

- Nutrition values are estimates.
- Hidden ingredients and exact portion sizes cannot be guaranteed from an image alone.
- User confirmation is required before logging.
