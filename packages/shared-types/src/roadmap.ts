import type { Task } from "./models.js";
import type { EventGroupWithDetails } from "./event-setup.js";

export interface TaskWithDependencies extends Task {
  dependsOnTaskIds: string[];
  categoryKey: string; // denormalized, so mobile can group without a separate category fetch
}

export interface GenerateRoadmapResponse {
  tasks: TaskWithDependencies[];
  removedTaskCount?: number; // tasks soft-deleted by a re-run
}

export interface EventGroupWithRoadmap extends EventGroupWithDetails {
  tasks: TaskWithDependencies[];
}

export interface TaskWithFullDependencies extends TaskWithDependencies {
  dependentTaskIds: string[];
}

export interface ListEventGroupTasksResponse {
  tasks: TaskWithFullDependencies[];
}

export interface UpdateTaskBody {
  status?: "not_started" | "in_progress" | "done";
  dueDate?: string | null;
  name?: string;
  description?: string | null;
  category?: string; // taskCategoryId (uuid) or categoryKey
}

export type RoadmapRegenMode = "keep_my_work" | "replace_all" | "add_missing";

export interface GenerateRoadmapBody {
  mode?: RoadmapRegenMode;
}

export interface TaskCategorySummary {
  id: string;
  categoryKey: string;
}

export interface CreateTaskBody {
  name: string;
  category: string; // taskCategoryId (uuid) or categoryKey
  dueDate: string;
  dependencyTaskIds?: string[];
}
