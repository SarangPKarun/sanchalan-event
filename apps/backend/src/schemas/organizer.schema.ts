import { z } from "zod";

export const updateProfileSchema = z.object({
  displayName: z.string().min(1),
  organizerType: z.enum(["individual", "family", "company", "committee"]),
});
export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;
