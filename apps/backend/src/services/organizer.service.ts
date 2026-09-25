import { prisma } from "../lib/prisma.js";
import type { UpdateProfileInput } from "../schemas/organizer.schema.js";

export function getMe(organizerId: string) {
  return prisma.organizer.findUniqueOrThrow({ where: { id: organizerId } });
}

export function updateProfile(organizerId: string, input: UpdateProfileInput) {
  return prisma.organizer.update({ where: { id: organizerId }, data: input });
}
