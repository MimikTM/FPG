/// Runtime tactical role. It is intentionally separate from PlayerPosition so
/// career/player data stays stable while Match2D can express football roles.
enum PlayerRole {
  goalkeeper,
  ballPlayingDefender,
  stopper,
  coverDefender,
  fullBack,
  attackingFullBack,
  anchor,
  boxToBox,
  playmaker,
  wideWinger,
  invertedWinger,
  insideForward,
  targetForward,
  poacher,
  pressingForward,
  falseNine,
}
