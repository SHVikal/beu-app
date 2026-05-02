import { env } from "./env.js";

export const openAIConfig = {
  apiKey: env.openAIAPIKey,
  visionModel: env.openAIVisionModel,
  textModel: env.openAITextModel
};

export function isOpenAIConfigured(): boolean {
  return openAIConfig.apiKey.trim().length > 0;
}
