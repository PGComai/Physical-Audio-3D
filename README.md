# Physical-Audio-3D
A Godot addon that adds (more) realistic 3D audio behavior.

## How to use
Add a PhysicalAudio3D node to your scene. Set the Audio Target to the node which will be hearing the audio.

Your scene MUST have a NavigationRegion3D node with a NavigationMesh for the audio to move around obstacles.

Currently this addon works best in single-floor enclosed spaces, like DOOM-style maps.
