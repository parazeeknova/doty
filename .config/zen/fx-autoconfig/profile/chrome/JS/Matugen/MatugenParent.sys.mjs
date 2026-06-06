// MatugenParent - parent side of the Matugen JSWindowActor.
// Runs in the chrome (browser) process. The bridge broadcasts theme
// updates via sendAsyncMessage; this parent just exists to satisfy
// fx-autoconfig's actor definition (parent esModuleURI is required).

"use strict";

export class MatugenParent extends JSWindowActorParent {
  receiveMessage(message) {
    return null;
  }
}
