import { Router, type Router as RouterType } from "express";
import { requireActiveOrganizer, requireAuth, requireRole } from "../middleware/auth.middleware.js";
import { listEventTypeProfiles } from "../config/event-type-profiles.js";
import { generateEventProfileSchema } from "../schemas/event-profile.schema.js";
import { generateEventProfile } from "../services/event-profile-generator.service.js";

export const eventTypeRouter: RouterType = Router();
eventTypeRouter.use(requireAuth, requireRole("organizer"), requireActiveOrganizer);

// The creation-flow definition for every event type. Static, so clients can cache it.
eventTypeRouter.get("/", (_req, res) => {
  res.status(200).json(listEventTypeProfiles());
});

// Writes the question set for an event type we have no form for (an LLM call, so it can take a while).
eventTypeRouter.post("/generate", async (req, res, next) => {
  try {
    const { description } = generateEventProfileSchema.parse(req.body);
    res.status(200).json(await generateEventProfile(req.auth!.userId, description));
  } catch (err) {
    next(err);
  }
});
