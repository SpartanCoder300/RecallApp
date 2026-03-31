## Product Idea Doc — “Daily Recall App” (Working Name)

---

# 1. Core Idea

An iOS app that helps users **remember what they learn during the day** by combining:

* frictionless capture
* daily recall sessions
* spaced repetition
* optional AI-based recall scoring

**Core promise:**

> “Stop forgetting what you learned today.”

---

# 2. Target User

### Primary

* Developers / engineers
* Knowledge workers
* Curious learners
* Students (secondary)

### Traits

* Learn things daily but forget most of it
* Already use Notes / bookmarks / screenshots
* Want to improve memory but hate “study tools”

---

# 3. Problem

* People **capture information but don’t retain it**
* Notes apps = storage, not learning
* Flashcard apps = too heavy / academic
* Self-testing manually = high friction

---

# 4. Solution

A **low-friction daily memory system**:

### Flow

1. During day → capture terms/concepts
2. Night → recall them from memory
3. Later → spaced repetition (days/weeks)

---

# 5. Core Features (MVP)

### 1. Capture (MOST IMPORTANT)

* 1-tap entry
* Just:

  * term/title
  * optional note
* Voice input support
* Lock screen / widget capture

---

### 2. Daily Recall Session

* Full screen, one item at a time
* Show only:

  * term
* User:

  * thinks
  * optionally types/speaks answer

---

### 3. Scoring

#### MVP

* manual:

  * Easy
  * Hard
  * Forgot

#### V2 (Differentiator)

* AI scoring:

  * Correct / partial / wrong
  * highlights missing concepts

---

### 4. Spaced Repetition

* automatic scheduling:

  * same day
  * next day
  * 1 week
  * 1 month

No user configuration

---

### 5. Minimal Insights

* “You’re forgetting X topics”
* “Retention this week”

(keep light, not dashboard-heavy)

---

# 6. Differentiation

## What exists

* Anki → powerful but complex
* Notes → simple but passive
* Recall apps → still feel like study tools

## Your wedge

> “Fast capture + effortless recall + beautiful UX”

---

# 7. UX / UI Principles

### Must feel:

* calm
* premium
* focused

### Design rules

* no clutter
* no lists during recall
* full-screen cards
* smooth animations
* subtle haptics

### Avoid

* mandatory organisation (every item must belong to something)
* complex category setup before first use
* nested folders or hierarchies
* dashboards
* gamification

### Collections — the one exception to "no organisation"

Collections are lightweight named groups (e.g. "Interview Prep", "IoT Concepts") that let users scope a review session to a specific context. They are the only organisational layer this app will ever have.

**Hard rules for Collections:**
* Always optional — items exist and schedule without one
* Never shown during Quick Add capture — zero friction at the point of capture
* Assigned after capture, via an edit flow or list action
* One collection per item (no multi-tagging)
* Created on demand, not pre-configured on first launch
* A focused session can filter by collection; the default session sees everything due

---

# 8. What Wins vs What Fails

## Wins

### 1. Capture speed

* faster than Notes
* instant access (widget / voice)

### 2. Review experience

* simple, immersive
* not “study mode”

### 3. AI that feels helpful

* short feedback
* not verbose

### 4. Habit formation

* daily loop
* small time commitment

---

## Fails

### 1. Too much setup

* mandatory categories, complex fields → kills usage
* Collections are permitted but must never appear in the capture flow

### 2. Feels like school

* flashcards, quizzes → people quit

### 3. Slow UX

* AI delays
* loading screens

### 4. Overengineering

* too many features early

### 5. Not beating Notes

* if it’s not faster → no reason to switch

---

# 9. AI Strategy

### Use cases

* score recall answers
* generate definitions (optional)
* highlight missing concepts

### Constraints

* must be fast
* must be optional
* fallback to manual rating

### Platform

* Apple Intelligence (on-device when available)
* fallback cloud model

---

# 10. Monetization Strategy

## Model: Freemium + Subscription

---

### Free Tier

* unlimited capture
* manual recall scoring
* basic spaced repetition
* limited daily reviews

---

### Paid Tier ($5–10/month or $40–60/year)

* AI scoring
* voice recall
* unlimited reviews
* smarter scheduling
* insights
* premium UX features (themes, etc.)

---

## Key principle

> Charge for “thinking assistance,” not storage

---

## What users pay for

* better memory
* less effort
* feeling sharper

---

## What they won’t pay for

* simple note storage
* reminders
* generic flashcards

---

# 11. Pricing

### Recommended

* $6.99/month
* $49/year

### Optional

* $25–30 lifetime (early users only)

---

# 12. Retention Strategy

* daily notification:

  * “Recall today’s learnings”
* short sessions (<3 min)
* visible progress over time

Goal:
👉 become a daily habit like journaling

---

# 13. Risks

### 1. Behavior risk

* users don’t stick with recall habit

### 2. Competition

* Notes is “good enough”

### 3. AI friction

* typing answers feels heavy

### 4. Market confusion

* seen as “just another flashcard app”

---

# 14. Validation Plan

### Step 1

* build ultra-simple MVP

### Step 2

* test:

  * do users prefer this over Notes?

### Step 3

* measure:

  * daily retention
  * review completion rate

---

# 15. Positioning

## Bad positioning

* “AI spaced repetition app”
* “flashcards for life”

## Good positioning

* “Remember what you learn”
* “Stop forgetting things”
* “Your daily memory habit”

---

# 16. Overall Rating

* Idea: **7/10**
* With strong UX + AI: **8.5–9/10**

---

# Final Take

This succeeds if:

* it’s **simpler than Notes**
* it’s **more effective than doing nothing**
* it **feels good to use daily**

It fails if:

* it becomes a productivity tool
* it adds friction
* it looks like a study app

---
