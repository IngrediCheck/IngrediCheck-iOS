---
name: mk-reply-guy
description: Find Reddit posts and craft genuine comments to pitch IngrediCheck. Walk through posts one by one, propose comments, get approval, then post via API.
disable-model-invocation: true
argument-hint: [search-terms|subreddit]
allowed-tools:
  - Bash(*)
  - WebSearch
---

# Reddit Post Discovery & Commenting for IngrediCheck

Find Reddit posts where we can comment to pitch IngrediCheck 2.0. Walk through posts one by one: show the post, propose a comment, get approval, then post via the Reddit API.

## Trigger: /mk-reply-guy

When the user runs **/mk-reply-guy** (or asks for "mk-reply-guy" / "reply guy" / "Reddit outreach"):

1. **Run the Procedure** below from Step 0 (auth check), then Step 1 (search), and keep proposing posts and comments until the user stops.
2. Do not ask for confirmation before starting; begin immediately.

## Setup (Prerequisites)

Before using this skill, the following must be configured once:

### 1. Register a Reddit app
1. Go to https://www.reddit.com/prefs/apps
2. Click "create another app..."
3. Choose type: **script**
4. Set redirect URI to `http://localhost:8080` (unused but required)
5. Note the **client ID** (under the app name) and **client secret**

### 2. Add Reddit credentials to `.env`
Add these variables to the `.env` file in the repo root (already gitignored):
```
REDDIT_CLIENT_ID=your_client_id
REDDIT_CLIENT_SECRET=your_client_secret
REDDIT_USERNAME=your_reddit_username
REDDIT_PASSWORD=your_reddit_password
REDDIT_USER_AGENT=IngrediCheck-ReplyGuy/1.0 by /u/your_reddit_username
```

### 3. Required OAuth scopes
The helper script requests these scopes automatically: `identity`, `read`, `submit`

## App Details

- **Name:** IngrediCheck (version 2.0)
- **Main Features:**
  - Family food notes
  - Personalized analysis of packaged food ingredients when grocery shopping
  - Free for early adopters
- **Links (include in every comment):**
  - https://www.ingredicheck.app/
  - https://apps.apple.com/us/app/ingredicheck/id6477521615

## Search Strategy

### Banned subreddits (do not search or propose)
- **r/FoodAllergies** — we are banned; skip any candidate from this sub.

### Target Subreddits
Cast a wide net across these; prioritize subs where people discuss checking ingredients on packaged foods, labels, or shopping with restrictions. Prefer subs with recent activity (browse `/new/` or check that posts are from the last month). Do not use banned subreddits (see above).

**Ingredient- and label-focused (high relevance)**
- r/ultraprocessedfood (weekly "Is this UPF?" product threads; very active)
- r/FoodLabels ("What's in your food?"; reading labels at the store; open posting)
- r/DoesThisTasteOff
- r/mildlyinfuriating (product/recipe changes)
- *Restricted (approved users only; do not try to post):* r/ingredients, r/onofffood

**Allergies & food allergies**
- *Restricted (approved users only; do not try to post):* r/Allergy, r/sulfiteallergy
- r/Allergies
- r/peanutallergy

**Celiac, gluten-free, intolerance**
- r/Celiac
- r/GlutenFree
- r/glutenfree
- r/GlutenFreeCooking
- r/glutenfreecooking
- r/glutenscience
- r/glutenfreememes
- r/glutenfreefoodporn
- r/glutenfreerecipes
- r/LactoseIntolerant
- r/lactoseintolerance
- r/DairyFree
- r/dairyfree
- r/EosinophilicE

**Diet & condition-specific**
- r/MCAS
- r/MastCellDiseases (related: r/MCAS)
- r/HistamineIntolerance
- r/FODMAPS
- r/LowFODMAP
- r/lowfodmap
- r/SIBO
- r/Dysautonomia (related: r/SIBO)
- r/Paleo (related: r/SIBO)
- r/ibs
- r/IBS
- r/GERD
- r/ConstipationAdvice
- r/shittingadvice
- r/HumanMicrobiome
- r/Microbiome
- r/AutoImmuneProtocol
- r/Whole30
- r/Keto
- r/keto
- r/IBD
- r/CrohnsDisease
- r/UlcerativeColitis
- r/PSC (primary sclerosing cholangitis; related: r/IBD)
- r/Hashimotos
- r/Candida (related: r/IBD, r/LowFODMAP)
- r/migraine (food triggers, tyramine, MSG; pick threads about label reading / avoiding triggers)
- r/POTS (related: r/Dysautonomia)
- r/ehlersdanlos
- r/Fibromyalgia
- r/Sjogrens
- r/autoimmunity
- r/Lyme
- r/MEAction
- r/autoimmunehepatitis (related: r/PSC)
- r/paleorecipes (related: r/Paleo)
- r/frugalpaleo (related: r/Paleo)
- r/grainfree (related: r/Paleo)
- r/primalmealplan (related: r/Paleo)

**Other diet-focused** (named diets, calorie/weight, timing, volume, meal prep)
- *Carnivore / zerocarb / very low carb:* r/carnivore, r/zerocarb, r/zerocarbrecipes, r/ZeroCarbMeals, r/meatogains
- *Mediterranean / DASH / MIND:* r/mediterraneandiet, r/DASHdiet (sodium/ingredient awareness), r/MINDdiet (brain health; Mediterranean–DASH hybrid)
- *Low carb / keto-adjacent:* r/lowcarb, r/ketoscience (research; label/ingredient discussions)
- *Elimination / triggers:* r/EliminationDiet
- *Intermittent fasting / timing:* r/IntermittentFasting
- *Calorie-aware / CICO / weight:* r/loseit, r/CICO, r/1200isplenty, r/1500isplenty, r/1200realfood, r/Vegan1200isPlenty, r/1200isPlentyKeto, r/caloriecount
- *Volume / low-cal cooking:* r/Volumeeating, r/LowCalorieCooking, r/LowCalFoodFinds
- *Meal prep / planning:* r/MealPrepSunday
- *Other diet types:* r/whole30 (30-day reset; we also list under condition-specific), r/Atkins (low-carb), r/psmf (protein-sparing modified fast), r/flexitarian, r/gainit (weight-gain diet), r/diabetes (diabetic eating; labels/carbs), r/PCOSloseit (PCOS + diet)
- *Diet/health general:* r/Health, r/FixMyDiet, r/PublicHealth, r/Dietetics, r/Supplements, r/WomensHealth, r/MensHealth

**Plant-based & ethical eating**
- r/vegan
- r/VeganActivism (related: r/vegan)
- r/VeganRecipes
- r/veganrecipes
- r/VeganFitness (related: r/vegan)
- r/VeganFoodPorn (related: r/vegan)
- r/vegetarian
- r/PlantBasedDiet
- r/WholeFoodsPlantBased
- r/EatCheapAndVegan (vegan grocery, budget, product picks)
- r/glutenfreevegan
- r/ketorecipes
- r/veganize (related: r/VeganFoodPorn)
- r/Veganism
- r/vegangifrecipes
- r/ShittyVeganFoodPorn
- r/planetbaseddiet
- r/ZeroWasteVegans (related: r/VeganActivism)

**Skin, asthma, and trigger-aware**
- r/eczema
- r/Psoriasis
- r/Asthma
- r/nontoxicpom

**General food, labels, and shopping**
- r/nutrition
- r/HealthyFood
- r/EatCheapAndHealthy
- r/fitmeals
- r/AskRedditFood
- r/CostcoWholesale
- r/BuyFromEU

**Recipe subreddits** (use only when post is about ingredient labels on packaged products, not pure recipe discussion)
- r/Recipes
- r/VegRecipes
- r/SlackerRecipes
- r/Cooking
- r/MiniMeals
- r/TrailMeals

**Process:** Search within these subs (e.g. subreddit search with `restrict_sr=1`), and/or browse `/new/` when search is sparse. Add other subs where people discuss ingredients, labels, allergies, or grocery shopping.

### Search Terms
- "ingredients changed" / "label changed" / "recipe change"
- "reading food labels" / "checking ingredients"
- "packaged food ingredients" / "grocery shopping ingredients"
- "food allergies" / "allergen checking"
- "how do you shop" / "shopping with allergies"
- "scan product" / "scanning labels" / "barcode scanner"
- "ingredient list" / "reading labels" / "checking labels"

### Search Focus
**Prioritize posts specifically about:**
- Checking ingredient labels on packaged products
- Confusion over ingredient lists
- Using apps/tools to scan or check products
- Reading labels for allergens or dietary restrictions

**Avoid posts about:**
- Nutrition facts, serving sizes, calories, macros
- Restaurant items without labels
- General food safety questions without ingredient focus
- Cooking recipes (unless specifically about checking packaged ingredient labels)

### Search Filters
- Time: `t=month` (recent, non-archived posts)
- Sort: `sort=new` (most recent first)
- Avoid archived posts (Reddit archives after 6 months)

### Search Process
1. Search across all of Reddit or within specific subreddits using the Reddit API
2. Filter for posts from the past month (`t=month`)
3. **Skip archived/locked posts** - check `archived` and `locked` boolean fields in the API response (see Procedure Step 2)
4. Prioritize posts with engagement (comments, upvotes)

## Comment Writing Guidelines

### Critical Rules
1. **ALWAYS verify the post is NOT archived/locked BEFORE proposing** - Check `archived` and `locked` boolean fields in the API response. If either is `true`, skip immediately and move to the next candidate. Do NOT propose a comment on archived or locked posts.
2. **ALWAYS read the full post AND top 5-10 comments before proposing a comment**
3. **ALWAYS check post relevance first** - Use the "Post Relevance Checklist" in "Lessons Learned" section. Skip posts about nutrition info, restaurant items without labels, or general food questions without ingredient checking focus.
4. **ALWAYS thoroughly check if user already commented** - Query `/user/{username}/comments` via API and check `link_id`. If user says "we already commented," trust them and skip immediately.
5. Make it relevant to the specific post and thread
6. Reference other comments, OP's phrasing, or shared pain points
7. Use "I built" or "I created" (not "I use")
8. Match the tone and style of other comments in the thread
9. **Do NOT use em dashes (—)** in proposed comments. Use regular hyphens (-) or parentheses instead.
10. **Be sensitive to context** - Avoid promoting on posts about severe medical crises or very distressing symptoms unless you can offer genuine help without trivializing their situation.

### Comment Structure
- **Opening:** Direct observation that ties to the post (e.g. "I noticed you're trying to identify and avoid [X]."). Avoid performative empathy; keep it simple and genuine.
- **Middle:** Brief explanation of how IngrediCheck helps. When describing the app, use **user-first order**: "You add your own triggers (e.g. X, Y, or whatever you're avoiding), then scan product labels while you shop" — not "you scan and then add triggers."
- **Features:** Mention family food notes + personalized ingredient analysis (and saving products that work)
- **Optional:** Future feature (e.g., "notify when ingredients change") only if relevant
- **Close:** Links + "free for early adopters"

### When to propose what kind of comment
Choose the angle that best matches the post so the comment feels relevant, not generic.

- **Ingredients changed / label changed / recipe change / "they changed the formula" / frustration that a product changed**  
  Lead with the **"notify when ingredients change"** angle: ask if they'd be interested in an app that notifies them when the ingredient list of their favorite products changes, say you're considering adding this feature to IngrediCheck, then plug current features (family food notes, personalized ingredient analysis when you scan) and both links + "free for early adopters." Do not lead with "notify when ingredients change" on posts that are *not* about products changing.

- **General label reading / checking ingredients / shopping with allergies or restrictions**  
  Lead with **current features**: family food notes and personalized ingredient analysis when you scan a label. Optionally mention the future "notify when ingredients change" feature only if it fits the thread.

- **Specific dietary triggers (FODMAPs, salicylates, benzoates, rare allergens)**  
  Use the **beta-testing invitation** approach: invite them to try IngrediCheck for their specific triggers and offer to improve the app based on their feedback; then mention current features and links.

- **Other apps or tools mentioned (Fig, Checkit, Spoonful, Monash, etc.)**  
  Lead with: IngrediCheck can do the same thing (e.g. flag gluten). Then emphasize it's **more general and flexible**: if someone has other restrictions on top of the main one (e.g. gluten + dairy), or different people in the family have different restrictions, IngrediCheck gives **personalized analysis for each person's unique needs**. Avoid over-indexing on technical differentiators (e.g. "scan the label vs barcode") unless the user asks; prefer the "flexible, multi-restriction, family/personalized" angle. Include family food notes, both links, and "free for early adopters."

### What Works
- Referencing another commenter's tool/method (e.g., "Someone mentioned using Fig app...")
- Using OP's own terminology (e.g., "sent to the backrooms")
- Addressing specific pain points mentioned in the thread
- Positioning as a tool that solves the exact problem being discussed
- Conversational, helpful tone
- **Beta-testing invitation approach:** For posts where users have specific dietary needs (e.g., salicylates, benzoates, FODMAPs), invite them to test IngrediCheck for their specific triggers and offer to improve it based on their feedback. This creates a collaborative, helpful tone rather than pure promotion.

### What Doesn't Work
- Generic templates that ignore the thread context
- Leading with "notifies when ingredients change" when the post is about something else
- Comments that feel like ads rather than genuine participation
- Not reading the full post/comments first
- Ignoring the actual question/topic
- **On "other apps mentioned" threads:** Leading with technical differentiators (e.g. "scan the label not just barcode," "middle ground") instead of the preferred angle: IngrediCheck can do the same (e.g. flag gluten), but is more general and flexible for multiple restrictions per person or different family members' needs.

### Comment pitfalls (avoid these)
- **Never claim to share OP's condition or allergies.** Do not say "I'm the same with egg and nuts," "I have X too," or similar when the commenter (IngrediCheck founder) does not have that allergy or condition. It is dishonest. Tie to the thread by referencing the *problem* (e.g. reading labels, decoding ingredients) without falsely claiming personal experience.
- **Do not use performative empathy.** Avoid lines like "That feeling is so real," "I got tired of doing that myself," or "I know how overwhelming it is" unless they are genuine. They often sound inauthentic and can imply shared experience you don't have. Prefer a **direct, observational opening** instead: e.g. "I noticed you're trying to identify and avoid [specific thing from their post]." Then plug the app. Simple and honest beats trying to sound relatable.
- **Do not tie the app to "not trusting labels."** IngrediCheck helps users *read and interpret* labels (decode ingredients, match to their list, get personalized analysis). It does NOT address whether the label is accurate or whether to trust the manufacturer. If you don't trust the label, scanning and analyzing it is pointless. Position the app as helping with *reading/decoding/analyzing* labels and matching them to the user's restrictions. Avoid framing like "when you don't trust the label," "not quite trusting them," or "the problem of not trusting labels."

## Workflow

1. **Authenticate** via Reddit API (Step 0) and confirm username
2. **Search** for recent posts using the Reddit API search endpoint
3. **Read the post** via API - full body, top comments, discussion tone
4. **Propose a comment** that:
   - Answers the question or adds to the discussion
   - References specific elements from the thread
   - Naturally introduces IngrediCheck as relevant
   - Includes both links
5. **Get user approval** (they may request edits)
6. **Post the comment via API** after approval (Step 4)
7. **Move to the next post**

## Example Comment Template (Tailor Each Time)

```
[Opening: direct observation, e.g. "I noticed you're trying to identify and avoid [X]." Keep it simple; no performative empathy.]

I built an app for that: you add your own triggers (e.g. [relevant examples], or whatever you're avoiding), then scan product labels while you shop. It flags matches so you get a quick read in the aisle, and you can save products that work so you're not re-checking next time. [Optional: "Still early and I'm improving it based on feedback, so if you try it and something's wrong or missing, I'd love to hear it."] Free for early adopters:

https://www.ingredicheck.app/
https://apps.apple.com/us/app/ingredicheck/id6477521615
```

**App flow to use in comments:** Describe as "you add your own triggers (...), then scan product labels while you shop" — user sets their list first, then scans when shopping. Do not lead with "you scan the ingredient list and add your triggers."

## Important Notes

- **Quality over quantity:** Better to find 3-5 highly relevant posts than 20 generic ones
- **Authenticity matters:** Comments should feel like genuine participation, not promotion
- **Context is everything:** Each comment must be tailored to its specific post and thread
- **Human-in-the-loop:** Always get user approval before posting. The API posts comments directly - there is no undo.
- **Always verify post is NOT archived/locked before proposing:** Check the `archived` and `locked` boolean fields in the API response. If either is true, skip immediately.
- **Skip posts where user already commented:** Query `/user/{username}/comments` and check `link_id` against the current post. Never propose a post if the current Reddit user has already left a comment on it; skip to the next candidate.

## Lessons Learned & Critical Relevance Criteria

### What IngrediCheck IS For:
- **Ingredient analysis on packaged products with scannable labels** - This is the core use case. The app helps users *read and interpret* the label (decode ingredients, match to their list, get personalized analysis). It does not verify whether the label is accurate or address "trust" in manufacturers.
- Posts about reading/checking ingredient labels on grocery store products
- Posts about identifying allergens or dietary triggers in packaged foods
- Posts about confusion over ingredient lists on product labels
- Posts where people mention using other apps (Fig, Spoonful, Monash) for ingredient checking

### What IngrediCheck is NOT For:
- **Nutrition information** - IngrediCheck does NOT help with serving sizes, calories, macros, or nutrition facts. Skip posts about nutrition data.
- **Restaurant items without labels** - IngrediCheck is for scanning product labels, not restaurant menus or items without scannable labels (e.g., Chipotle, fast food, etc.)
- **General food questions** - Skip posts that are just asking "is X safe?" without focusing on ingredient checking
- **Cooking recipes** - Skip posts about cooking or recipe modifications unless they specifically mention checking ingredient labels on packaged products

### Post Relevance Checklist (MUST pass all):
1. ✅ Post is about checking ingredients on **packaged products** (not restaurants)
2. ✅ Post involves **reading labels** or **scanning products** (not just general food questions)
3. ✅ Post is NOT about nutrition information (serving sizes, calories, macros)
4. ✅ Post is NOT about restaurant items without scannable labels
5. ✅ Post shows genuine need for ingredient analysis tool

### Comment authenticity (from user feedback):
- **Opening:** Use a direct observation (e.g. "I noticed you're trying to identify and avoid [X]."). Do not use performative empathy like "That feeling is so real" or "I got tired of doing that myself" — it does not sound genuine.
- **App description:** Use user-first order: "You add your own triggers (...), then scan product labels while you shop." Do not say "you scan the ingredient list and add your triggers."

### Tone & Sensitivity Guidelines:
- **Avoid insensitive comments** - If a post involves severe health struggles, medical crises, or very distressing symptoms, be extra careful. The comment should offer genuine help without trivializing their situation.
- **Match the thread's emotional tone** - If people are frustrated, acknowledge that. If they're celebrating a win, match that energy.
- **Don't promote on posts about severe medical issues** - If someone is describing losing the ability to eat, severe reactions, or medical emergencies, skip the post or be extremely empathetic and helpful without heavy promotion.

### Duplicate Comment Prevention:
- **ALWAYS check via API** - Query `/user/{username}/comments?limit=100` and check if any returned comment has a `link_id` matching `t3_{post_id}` for the current post. This is deterministic and does not depend on comment tree pagination.
- Also search the post's comment tree for "IngrediCheck" or "ingredicheck" (case-insensitive) as a secondary check.
- If ANY match is found, IMMEDIATELY skip - do NOT propose.
- **User feedback overrides** - If user says "we already commented on this" even if your check didn't find it, trust them and skip immediately.

## Procedure

Execute these steps using the Reddit API via the `reddit-api.sh` helper script. The script is at `.claude/skills/mk-reply-guy/scripts/reddit-api.sh`.

### Step 0 — Authenticate via Reddit API

1. Source the helper script and validate credentials:
   ```bash
   source .claude/skills/mk-reply-guy/scripts/reddit-api.sh
   reddit_load_config
   ```
2. Get an OAuth token and verify identity:
   ```bash
   source .claude/skills/mk-reply-guy/scripts/reddit-api.sh
   reddit_api GET /api/v1/me | jq '{name, comment_karma, link_karma}'
   ```
3. Note the `name` field - this is the Reddit username. You will need it for duplicate detection.
4. **If auth fails with a 2FA error:** Ask the user for their current OTP code, then retry with `REDDIT_OTP=<code> reddit_api GET /api/v1/me`.
5. Do not proceed to Step 1 until auth succeeds.

### Step 1 — Search for posts

Search within target subreddits or across Reddit using the API:
```bash
source .claude/skills/mk-reply-guy/scripts/reddit-api.sh
reddit_api GET "/r/SUBREDDIT/search" \
  --data-urlencode "q=QUERY" \
  --data-urlencode "sort=new" \
  --data-urlencode "t=month" \
  --data-urlencode "limit=25" \
  --data-urlencode "restrict_sr=1" \
| jq '[.data.children[].data | {id, title, subreddit, selftext: .selftext[:200], score, num_comments, created_utc, archived, locked, permalink}]'
```

For cross-subreddit search, use `/search` instead of `/r/SUBREDDIT/search` and omit `restrict_sr`.

Present the results as a numbered list with title, subreddit, age, and comment count.

### Step 2 — Read and validate each candidate post

- **Skip banned subreddits:** Do not read or propose posts from r/FoodAllergies (we are banned there). If a search result is from a banned sub, skip it.

- **Fetch the full post and comments via API:**
  ```bash
  source .claude/skills/mk-reply-guy/scripts/reddit-api.sh
  reddit_api GET "/r/SUBREDDIT/comments/POST_ID" \
    --data-urlencode "limit=100" \
    --data-urlencode "sort=top"
  ```
  The response is a two-element JSON array: `[0]` is the post, `[1]` is the comment tree.

- **CRITICAL: Check archived/locked status BEFORE proposing:**
  Extract `archived` and `locked` from the post data: `.[0].data.children[0].data | {archived, locked}`. If either is `true`, **SKIP immediately**.

- **CRITICAL: Check for duplicate comments BEFORE proposing:**
  1. Query the user's recent comments:
     ```bash
     source .claude/skills/mk-reply-guy/scripts/reddit-api.sh
     reddit_api GET "/user/USERNAME/comments" \
       --data-urlencode "limit=100" \
     | jq '[.data.children[].data | {link_id, subreddit, body: .body[:100]}]'
     ```
  2. Check if any returned comment has `link_id` equal to `t3_POST_ID` (the current post's ID).
  3. Also search the post's comment tree for "IngrediCheck" or "ingredicheck" (case-insensitive).
  4. **If ANY match is found, IMMEDIATELY skip this post. Do NOT propose.**
  5. **If user says "we already commented on this," trust them and skip immediately.**

- **CRITICAL: Check post relevance using the "Post Relevance Checklist" above:**
  1. Is this about checking ingredients on **packaged products**? (Skip if restaurant items without labels)
  2. Does this involve **reading labels** or **scanning products**? (Skip if just general food questions)
  3. Is this about **nutrition information**? (If yes, skip)
  4. Is this about **restaurant items without scannable labels**? (If yes, skip)
  5. Does this show genuine need for ingredient analysis tool? (If no, skip)

- Read the full post body (`.selftext`) and top comments from the API response.
- **Check tone/sensitivity:** If post involves severe health struggles or medical crises, be extra careful with comment tone or skip if inappropriate.

### Step 3 — Propose a comment
- Present the post title, body excerpt, and top comments to the user so they have context.
- Draft a comment using the Comment Writing Guidelines and Example Template above. Use a direct observational opening (e.g. "I noticed you're trying to...") and describe the app as: add your triggers first, then scan product labels while shopping.
- Tie the opening to the post and other comments; include both app links and "free for early adopters."
- Present the comment to the user and ask for approval or edits.

### Step 4 — Post the comment via API
- **Only after user explicitly approves**, post the comment:
  ```bash
  source .claude/skills/mk-reply-guy/scripts/reddit-api.sh
  reddit_api POST "/api/comment" \
    --data-urlencode "api_type=json" \
    --data-urlencode "thing_id=t3_POST_ID" \
    --data-urlencode "text=COMMENT_TEXT"
  ```
- Parse the response: check that `.json.errors` is an empty array AND that `.json.data.things[0].data` exists.
- **On success:** Show the permalink (`json.data.things[0].data.permalink`) and confirm the comment was posted.
- **On failure:** Show the error details. Common errors: rate limiting (wait and retry), RATELIMIT (show time to wait), captcha required (inform user), permission denied (sub may restrict new commenters).

### Step 5 — Next post
- Repeat from Step 2 for the next candidate until the user stops or asks for a new search.

## Usage

When the user asks to find Reddit posts or work on Reddit outreach, follow the **Procedure** above. The `reddit-api.sh` helper script handles all API communication.
