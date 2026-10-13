// Event type profiles: the creation flow for each event type, as data. A client renders these
// generically, so a new event type is new data here, not a new screen.
//
// A question with `mapsTo` fills a top-level EventGroup field (and is validated by
// createEventGroupSchema). Every other answer goes into EventGroup.details.

export type QuestionKind =
  | "single_select"
  | "multi_select"
  | "chips"
  | "text"
  | "number"
  | "date"
  | "budget";

export type CoreField =
  | "name"
  | "region"
  | "religionOrTradition"
  | "primaryDate"
  | "guestCountEstimate"
  | "totalBudget"
  | "budgetTier";

export interface QuestionOption {
  value: string;
  label: string;
}

export interface Question {
  key: string;
  label: string;
  kind: QuestionKind;
  options?: QuestionOption[];
  /** Lets the user type a value that is not in `options`. */
  allowOther?: boolean;
  required?: boolean;
  /** Only ask when another answer (by key) equals this value. */
  showIf?: { key: string; equals: string };
  mapsTo?: CoreField;
}

export interface Step {
  id: string;
  title: string;
  subtitle?: string;
  questions: Question[];
}

export interface EventTypeProfile {
  eventType: string;
  version: number;
  steps: Step[];
}

const opts = (...pairs: [string, string][]): QuestionOption[] =>
  pairs.map(([value, label]) => ({ value, label }));

// Questions several event types share, defined once.
const FOOD_PREFERENCE: Question = {
  key: "foodPreference",
  label: "What food will you serve?",
  kind: "single_select",
  options: opts(["veg", "Vegetarian"], ["non_veg", "Non-vegetarian"], ["both", "Both"]),
};
const VENUE_STYLE: Question = {
  key: "venueStyle",
  label: "What kind of venue?",
  kind: "single_select",
  options: opts(["hall", "Banquet hall"], ["outdoor", "Outdoor / lawn"], ["home", "At home"], ["destination", "Destination"]),
};
const OUTSTATION_STAY: Question = {
  key: "outstationStay",
  label: "Will guests from other cities need a stay?",
  kind: "single_select",
  options: opts(["yes", "Yes"], ["no", "No"], ["some", "Some of them"]),
};
const ENTERTAINMENT: Question = {
  key: "entertainment",
  label: "Any entertainment?",
  kind: "multi_select",
  options: opts(["dj", "DJ"], ["live_music", "Live music"], ["games", "Games"], ["performer", "Magician / performer"]),
};

const nameStep = (label: string): Step => ({
  id: "basics",
  title: "Let's start",
  questions: [{ key: "name", label, kind: "text", required: true, mapsTo: "name" }],
});

const coreStep = (): Step[] => [
  {
    id: "when_and_who",
    title: "When and how many?",
    questions: [
      { key: "primaryDate", label: "Date", kind: "date", required: true, mapsTo: "primaryDate" },
      { key: "guestCountEstimate", label: "Roughly how many guests?", kind: "number", required: true, mapsTo: "guestCountEstimate" },
    ],
  },
  {
    id: "budget",
    title: "Your budget",
    questions: [
      { key: "totalBudget", label: "Total budget", kind: "budget", required: true, mapsTo: "totalBudget" },
      {
        key: "budgetTier",
        label: "How would you like to spend?",
        kind: "single_select",
        required: true,
        mapsTo: "budgetTier",
        options: opts(["essential", "Essential"], ["standard", "Standard"], ["premium", "Premium"], ["luxury", "Luxury"]),
      },
    ],
  },
];

const regionQuestion = (required = true): Question => ({
  key: "region",
  label: "Which city or region?",
  kind: "text",
  required,
  mapsTo: "region",
});

const WEDDING: EventTypeProfile = {
  eventType: "wedding",
  version: 1,
  steps: [
    nameStep("What should we call this wedding?"),
    {
      id: "tradition",
      title: "Your traditions",
      subtitle: "This shapes your rituals, tasks and budget.",
      questions: [
        regionQuestion(),
        {
          key: "religionOrTradition",
          label: "Religion or tradition",
          kind: "single_select",
          mapsTo: "religionOrTradition",
          allowOther: true,
          options: opts(["hindu", "Hindu"], ["muslim", "Muslim"], ["christian", "Christian"], ["sikh", "Sikh"], ["jain", "Jain"], ["interfaith", "Interfaith / civil"]),
        },
        { key: "community", label: "Community (optional)", kind: "text" },
        {
          key: "language",
          label: "Main language of the ceremony",
          kind: "single_select",
          allowOther: true,
          options: opts(["hindi", "Hindi"], ["english", "English"], ["marathi", "Marathi"], ["gujarati", "Gujarati"], ["bengali", "Bengali"], ["tamil", "Tamil"], ["telugu", "Telugu"], ["kannada", "Kannada"], ["malayalam", "Malayalam"], ["punjabi", "Punjabi"], ["odia", "Odia"], ["urdu", "Urdu"]),
        },
      ],
    },
    {
      id: "functions",
      title: "Which functions?",
      questions: [
        {
          key: "subEventsWanted",
          label: "Pick what you plan to have",
          kind: "multi_select",
          options: opts(["engagement", "Engagement"], ["haldi", "Haldi"], ["mehendi", "Mehendi"], ["sangeet", "Sangeet"], ["wedding", "Wedding"], ["reception", "Reception"]),
        },
        {
          key: "hostingSide",
          label: "Who is hosting?",
          kind: "single_select",
          options: opts(["bride", "Bride's side"], ["groom", "Groom's side"], ["both", "Both families"]),
        },
      ],
    },
    {
      id: "style",
      title: "Venue and food",
      questions: [VENUE_STYLE, FOOD_PREFERENCE, OUTSTATION_STAY],
    },
    ...coreStep(),
  ],
};

const BIRTHDAY: EventTypeProfile = {
  eventType: "birthday",
  version: 1,
  steps: [
    nameStep("What should we call this party?"),
    {
      id: "celebrant",
      title: "About the party",
      questions: [
        regionQuestion(),
        {
          key: "celebrant",
          label: "Whose birthday?",
          kind: "single_select",
          options: opts(["kid", "A child"], ["teen", "A teenager"], ["adult", "An adult"], ["milestone", "A milestone (e.g. 50th)"]),
        },
        { key: "theme", label: "Theme (optional)", kind: "text" },
        { key: "surprise", label: "Is it a surprise?", kind: "single_select", options: opts(["yes", "Yes"], ["no", "No"]) },
      ],
    },
    {
      id: "style",
      title: "Venue, food and fun",
      questions: [VENUE_STYLE, FOOD_PREFERENCE, ENTERTAINMENT],
    },
    ...coreStep(),
  ],
};

const CORPORATE: EventTypeProfile = {
  eventType: "corporate",
  version: 1,
  steps: [
    nameStep("What is the event called?"),
    {
      id: "kind",
      title: "About the event",
      questions: [
        regionQuestion(),
        {
          key: "corporateKind",
          label: "What kind of event?",
          kind: "single_select",
          required: true,
          options: opts(["conference", "Conference"], ["offsite", "Offsite"], ["launch", "Product launch"], ["team_party", "Team party"]),
        },
        {
          key: "duration",
          label: "How long?",
          kind: "single_select",
          options: opts(["one_day", "One day"], ["multi_day", "Multiple days"]),
        },
        { key: "needsAv", label: "Stage and AV needed?", kind: "single_select", options: opts(["yes", "Yes"], ["no", "No"]) },
      ],
    },
    {
      id: "logistics",
      title: "Food and travel",
      questions: [FOOD_PREFERENCE, OUTSTATION_STAY],
    },
    ...coreStep(),
  ],
};

const RELIGIOUS: EventTypeProfile = {
  eventType: "religious",
  version: 1,
  steps: [
    nameStep("What is the ceremony called?"),
    {
      id: "ceremony",
      title: "About the ceremony",
      questions: [
        regionQuestion(),
        {
          key: "religionOrTradition",
          label: "Religion or tradition",
          kind: "single_select",
          required: true,
          mapsTo: "religionOrTradition",
          allowOther: true,
          options: opts(["hindu", "Hindu"], ["muslim", "Muslim"], ["christian", "Christian"], ["sikh", "Sikh"], ["jain", "Jain"]),
        },
        {
          key: "ceremonyType",
          label: "Type of ceremony",
          kind: "single_select",
          allowOther: true,
          options: opts(["puja", "Puja"], ["naming", "Naming ceremony"], ["housewarming", "Housewarming"], ["anniversary", "Anniversary"]),
        },
        { key: "needsPriest", label: "Need a priest or officiant?", kind: "single_select", options: opts(["yes", "Yes"], ["no", "No"]) },
        { key: "communityFeast", label: "Community feast?", kind: "single_select", options: opts(["yes", "Yes"], ["no", "No"]) },
      ],
    },
    ...coreStep(),
  ],
};

const ENGAGEMENT_ONLY: EventTypeProfile = {
  eventType: "engagement_only",
  version: 1,
  steps: [
    nameStep("What should we call this engagement?"),
    {
      id: "details",
      title: "About the engagement",
      questions: [
        regionQuestion(),
        {
          key: "religionOrTradition",
          label: "Religion or tradition (optional)",
          kind: "single_select",
          mapsTo: "religionOrTradition",
          allowOther: true,
          options: opts(["hindu", "Hindu"], ["muslim", "Muslim"], ["christian", "Christian"], ["sikh", "Sikh"], ["jain", "Jain"]),
        },
        { key: "ringCeremony", label: "Ring ceremony?", kind: "single_select", options: opts(["yes", "Yes"], ["no", "No"]) },
        { key: "venueStyle", label: "Where?", kind: "single_select", options: opts(["home", "At home"], ["hall", "Banquet hall"]) },
      ],
    },
    ...coreStep(),
  ],
};

/** Used for `custom` and as the safe fallback for any type without its own profile. */
const GENERIC: EventTypeProfile = {
  eventType: "custom",
  version: 1,
  steps: [
    nameStep("What are you planning?"),
    {
      id: "about",
      title: "Tell us more",
      questions: [
        regionQuestion(),
        { key: "description", label: "Describe your event in a sentence", kind: "text" },
      ],
    },
    ...coreStep(),
  ],
};

const PROFILES: EventTypeProfile[] = [WEDDING, BIRTHDAY, CORPORATE, RELIGIOUS, ENGAGEMENT_ONLY, GENERIC];

/** Core field keys: a generated question may not reuse them. */
export const CORE_QUESTION_KEYS: string[] = [
  "name",
  "region",
  "religionOrTradition",
  "primaryDate",
  "guestCountEstimate",
  "totalBudget",
  "budgetTier",
];

/** A `custom` event's flow: name and place first, the LLM-written steps in the middle,
 * then the usual date, guests and budget. */
export function buildCustomProfile(generatedSteps: Step[]): EventTypeProfile {
  return {
    eventType: "custom",
    version: 1,
    steps: [
      nameStep("What are you planning?"),
      { id: "place", title: "Where?", questions: [regionQuestion()] },
      ...generatedSteps,
      ...coreStep(),
    ],
  };
}

export function listEventTypeProfiles(): EventTypeProfile[] {
  return PROFILES;
}

export function getEventTypeProfile(eventType: string): EventTypeProfile {
  return PROFILES.find((p) => p.eventType === eventType) ?? GENERIC;
}
