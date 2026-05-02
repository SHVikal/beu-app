# BeU Food Image Analysis

## Architecture
- The iOS app never stores or sends an OpenAI API key.
- The iOS app uploads the selected meal image to the backend as `multipart/form-data`.
- The backend converts the image to a base64 data URL and calls the OpenAI Responses API.
- The backend validates and sanitizes the structured JSON result before returning it to iOS.
- The user must review and confirm detected items before a meal can be logged.

## Why the API key is backend-only
- It prevents shipping the secret in the iOS bundle.
- It allows server-side validation, fallback handling, and future rate limiting.
- It keeps model choice configurable on the server through environment variables.

## Environment
Add these values to `backend/.env`:

```env
OPENAI_API_KEY=your_api_key_here
OPENAI_VISION_MODEL=gpt-5.4-mini
PORT=3000
```

## Endpoint
`POST /api/food/analyze-image`

### Request
- Content type: `multipart/form-data`
- Fields:
  - `userId`
  - `image`

### Success response
```json
{
  "analysisId": "analysis_123",
  "userId": "demo-user",
  "imageLocalPath": null,
  "imageRemoteUrl": null,
  "detectedItems": [
    {
      "id": "item_1",
      "name": "Grilled chicken",
      "estimatedPortion": "150g",
      "quantityGrams": 150,
      "confidence": "high",
      "calories": 250,
      "proteinGrams": 32.4,
      "carbsGrams": 4.2,
      "fatGrams": 8.1,
      "userConfirmed": false
    }
  ],
  "totalCalories": 250,
  "totalProteinGrams": 32.4,
  "totalCarbsGrams": 4.2,
  "totalFatGrams": 8.1,
  "confidence": "high",
  "notes": [
    "Nutrition values are estimates based on visible food items.",
    "Please confirm items and portions before logging."
  ],
  "createdAt": "2026-04-27T10:30:00.000Z"
}
```

### Error response
```json
{
  "error": true,
  "code": "IMAGE_ANALYSIS_FAILED",
  "message": "We could not analyze this image. Please try another photo."
}
```

## Prompt used
The backend sends this instruction to OpenAI:

> You are a food image analysis assistant for a wellness app called BeU. Analyze the uploaded meal photo. Identify visible food items, estimate portions and macros, return only structured JSON, be conservative, and avoid medical claims.

The full prompt lives in:
[OpenAIFoodVisionService.ts](/Users/avikal/Documents/New%20project/backend/src/services/OpenAIFoodVisionService.ts)

## Structured output schema
The backend forces the model into a strict schema with:
- `detectedItems`
- `totalCalories`
- `totalProteinGrams`
- `totalCarbsGrams`
- `totalFatGrams`
- `confidence`
- `notes`

Server-side, the backend:
- adds item ids
- sets `userConfirmed = false`
- recalculates totals from item values
- sanitizes negative or missing values

## Replacing the model later
Change the server model through:

```env
OPENAI_VISION_MODEL=your_preferred_model
```

No iOS changes are required as long as the JSON response shape stays the same.

## Known limitations
- Image-based nutrition is approximate.
- Hidden ingredients cannot be detected reliably.
- Portion sizes are estimates.
- User confirmation is required before logging.
- Non-food or blurry images may return no detected items.
