# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**//ROGUE_PROCESS** is a cyberpunk-themed roguelike game built with LÖVE (Love2D) and Lua. The game features:

- Turn-based tactical combat with AI cores and subroutines
- Procedural map generation using cellular automata
- Entity-component system with sprites and animations
- State machine-based game flow
- Particle effects and visual polish

## Running the Game

To run the game:

```bash
love .
```

The game requires LÖVE 2D framework. The configuration is in `conf.lua` with a native resolution of 640x360.

## Architecture Overview

### State Management

- **GameState.lua**: Central state manager handling transitions between menu, gameplay, and other states
- States are registered in `main.lua`: MainMenuState, GameplayState, NewRunState, SubroutineChoiceState, CoreModificationState
- Each state implements enter/leave/update/draw/keypressed lifecycle methods

### Core Game Systems

- **Entity.lua**: Base class for all game objects (player, enemies, pickups)
- **SpriteManager.lua**: Manages sprite sheets and quad definitions for rendering
- **WorldInitializer.lua**: Handles map generation and world setup
- **TurnManager**: Coordinates turn-based gameplay flow
- **CameraManager**: Handles viewport and camera movement
- **HUDManager**: Manages UI rendering and effects

### Game Entities

- **Player**: Main character with AI core system and subroutines
- **Enemies**: Various types in `src/core/enemies/` (SentryBot, DataLeech, FirewallNode, etc.)
- **Bosses**: Sector-based boss encounters in `src/core/bosses/`
- **Pickups**: Items and power-ups scattered throughout levels

### Configuration System

- **config.lua**: Central configuration file containing:
  - Color schemes and UI theming
  - Sprite and tile definitions
  - Map generation parameters
  - Audio/SFX definitions
  - Visual effects settings
- All configuration is accessed via `_G.Config`

### Rendering Pipeline

- Game renders to `MainSceneCanvas` at native resolution (640x360)
- Canvas is scaled to fit window while maintaining aspect ratio
- Pixel-perfect scaling with optional shader effects
- Sprite rendering uses nearest-neighbor filtering

### Audio System

- **SFX.lua**: Procedural sound effect generation
- Sound definitions in `config.lua` with frequency, duration, and waveform parameters
- No external audio files - all sounds generated programmatically

## Development Conventions

### File Organization

- **src/core/**: Core game systems and entities
- **src/states/**: Game state implementations
- **src/ui/**: UI components and helpers
- **src/utils/**: Utility modules and helpers
- **src/assets/**: Fonts, sprites, and other assets

### Sprite System

- All sprites defined in SpriteManager.lua with quad names
- Sprite size is 16x16 pixels (configurable in DEFAULT_SPRITE_DIMENSION)
- Entity rendering uses quadName instead of character representation
- Coordinate system: (0,0) is top-left of sprite sheet

### Entity System

- All game objects inherit from Entity base class
- Entities have position (x,y), quadName for rendering, and color tinting
- Health, status effects, and turn management built into base Entity
- Enemies implement AI through behavior patterns

### Global State

- Key systems exposed as globals: Config, GameState, Fonts, SpriteManager, SFX, MetaProgress
- MainSceneCanvas and CompositeShader available globally
- Package path configured to load modules from src/ directory

### Turn-Based Mechanics

- GameplayState manages turn flow through Mode enum
- Player actions trigger enemy turns
- Intent display system shows enemy planned actions
- Targeting mode for ranged abilities

### Visual Effects

- ParticleSystem for dynamic effects
- Animation system for smooth sprite transitions
- Color theming through Config.activeColors
- Support for scanlines and CRT effects (optional)

## Common Tasks

### Adding New Entities

1. Create class inheriting from Entity in appropriate directory
2. Define sprite quad in SpriteManager.lua
3. Implement entity-specific behavior (AI for enemies)
4. Add to appropriate spawn/generation systems

### Modifying UI

- UI colors and theming in Config.colors and Config.activeColors
- UI helper functions in src/ui/ui_helpers.lua
- HUD elements managed through HUDManager

### Map Generation

- Algorithm configurable in Config.mapGeneration
- Currently uses cellular automata with connectivity checking
- Tile definitions in Config.tile with walkability and transparency

### Adding States

- Create new state class with lifecycle methods
- Register in main.lua using GameState.register()
- Handle transitions with GameState.switch()
