import type { Task } from "./models.js";
import type { EventGroupWithDetails } from "./event-setup.js";

export interface TaskWithDependencies extends Task {
  dependsOnTaskIds: string[];
  categoryKey: string; // denormalized, so mobile can group without a separate category fetch
}

export interface GenerateRoadmapResponse {
  tasks: TaskWithDependencies[];
}

export interface EventGroupWithRoadmap extends EventGroupWithDetails {
  tasks: TaskWithDependencies[];
}
