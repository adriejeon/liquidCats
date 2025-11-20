# Project: Liquid Cat (고양이는 액체다)

## 1. Game Overview

- **Genre:** Physics-based Drop & Merge Puzzle (Suika-style).

- **Concept:** "Cats are Liquid." Cats are dropped into a glass container. When identical cats collide, they merge into a larger cat.

- **Core Loop:** Aim -> Drop -> Merge -> Score Up -> Repeat until Overflow.

## 2. Tech Stack

- **Framework:** Flutter (Dart)

- **Game Engine:** Flame

- **Physics Engine:** Flame Forge2D (Box2D port)

- **State Management:** Riverpod (Score, Game State)

- **Storage:** Hive (High Score persistence)

## 3. Key Features & Logic

### A. Physics & "Liquid" Feel (Crucial)

- **Physics Body:** Use `CircleShape` fixtures in Forge2D for stable rolling.

- **Visuals (Soft Body):** The physics body is rigid, but the visual sprite MUST act like a liquid.

  - **Impact:** Apply `ScaleEffect` (Squash & Stretch) on collision (e.g., width x1.2, height x0.8 -> elastic bounce).

  - **Idle:** Apply gentle breathing animation (Scale x0.98 <-> x1.02) when velocity is near zero.

  - **Squeeze:** Cats should look like they are filling the gaps.

### B. Game Object: The Container (Glass)

- **Implementation:** NO image files. Pure code using `CustomPainter`.

- **Layering (Z-Order):**

  1. Background Layer: Glass Back (Darker stroke, low opacity fill).

  2. Game Layer: Cats (Spawned inside the container).

  3. Foreground Layer: Glass Front (Highlights, reflection, high transparency) to make cats look *inside*.

- **Physics:** `StaticBody` walls (Left, Right, Bottom) matching the visual container.

### C. Cat Evolution (11 Stages)

- **Assets:** `cat_01.png` (Smallest) to `cat_11.png` (Largest/God).

- **Special Effects:**

  - Stage 9, 10, 11 (Tiger, Lion, God): Add random "Blink Eye" animation (Sprite switching).

### D. Game Rules

- **Merge:** Collision of two bodies of `type N` -> Remove both -> Spawn one body of `type N+1` at midpoint.

- **GameOver:** If a cat stays above the "Limit Line" for more than 3 seconds.

## 4. Folder Structure

- lib/

  - game/ (Flame Game logic)

  - components/ (CatBody, GlassContainer, etc.)

  - overlays/ (UI: Score, GameOver, Menu)

  - managers/ (Audio, Assets)

  - models/ (Cat data model)
