import { createApp } from "./app.js";
import { env } from "./lib/env.js";

createApp().listen(env.PORT, () => {
  console.log(`Sanchalan backend listening on port ${env.PORT}`);
});
