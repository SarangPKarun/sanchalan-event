import type { NextFunction, Request, Response } from "express";
import {
  approveProposalSchema,
  listProposalsQuerySchema,
  mergeProposalSchema,
  proposalIdParamSchema,
  proposeCategorySchema,
  rejectProposalSchema,
} from "../schemas/category-proposal.schema.js";
import * as service from "../services/category-proposal.service.js";

type Handler = (req: Request) => Promise<unknown>;

function handle(fn: Handler, successStatus = 200) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      res.status(successStatus).json(await fn(req));
    } catch (err) {
      next(err);
    }
  };
}

const idOf = (req: Request) => proposalIdParamSchema.parse(req.params).id;

export const proposeCategoryHandler = handle(
  (req) => service.proposeCategory(req.auth!.userId, proposeCategorySchema.parse(req.body)),
  201
);
export const listMyProposalsHandler = handle((req) => service.listMyProposals(req.auth!.userId));

export const listProposalsHandler = handle((req) =>
  service.listProposals(listProposalsQuerySchema.parse(req.query).status)
);
export const getProposalHandler = handle((req) => service.getProposal(idOf(req)));
export const approveProposalHandler = handle((req) =>
  service.approveProposal(idOf(req), req.auth!.userId, approveProposalSchema.parse(req.body))
);
export const rejectProposalHandler = handle((req) =>
  service.rejectProposal(idOf(req), req.auth!.userId, rejectProposalSchema.parse(req.body).reason)
);
export const mergeProposalHandler = handle((req) =>
  service.mergeProposal(idOf(req), req.auth!.userId, mergeProposalSchema.parse(req.body).vendorCategoryId)
);
