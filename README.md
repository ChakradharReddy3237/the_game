# The Game

A 2D platformer game built with Godot 4.5.1 featuring wall-jumping mechanics, enemy AI, and challenging levels.

## Features

- **Player Mechanics**
  - Smooth movement and jumping
  - Wall jump with stamina system
  - Gliding mechanics
  - Animated character with procedural antenna and cape physics

- **Enemy AI**
  - Worker Ant enemies with patrol, spot, and chase states
  - Intelligent pathfinding and player detection
  - Stomp mechanic to defeat enemies

- **Game Systems**
  - Death and respawn system
  - Camera follow with shake effects
  - Options menu with audio controls
  - Help screen with game instructions

## Controls

- **Movement**: Arrow Keys / WASD
- **Jump**: Space
- **Wall Jump**: Space (while on wall)
- **Pause**: ESC

## Development

### Requirements
- Godot Engine 4.5.1 or higher

### Running the Game
1. Open the project in Godot Engine
2. Press F5 or click "Run Project"

### Project Structure
```
assets/
  ├── audio/          # Sound effects
  ├── camera/         # Camera controllers
  ├── fonts/          # Game fonts
  ├── level_prefabs/  # Reusable level objects (spikes, etc.)
  ├── player/         # Player controller and UI
  ├── Prefab_kinda/   # UI prefabs (menus, pause screen)
  ├── sprites/        # Game sprites
  ├── tutorial/       # Tutorial dialogs
  └── worker_ant/     # Enemy AI and assets
Scenes/
  ├── main_menu.tscn  # Main menu scene
  └── testing_scene.tscn # Game level
```

## Credits

Created by Chakradhar Reddy

## License

This project is for educational purposes.
