import { createApp } from "./app.js";
import { env } from "./config/env.js";
import "./db/database.js";

const app = createApp();

app.listen(env.port, env.host, () => {
  console.log(`BeU backend listening on http://${env.host}:${env.port}`);
});
