const hit = roomSelections.find((selection) => {
  return x >= selection.x && x < selection.x + selection.width && y >= selection.y && y < selection.y + selection.height;
});

state.stage = typeof state.stage === 'string' ? state.stage : 'start';
state.leechShown = state.leechShown === true;

function say(text, nextStage = state.stage) {
  state.stage = nextStage;
  return displayText(text);
}

function showPatch(name, nextStage) {
  state.stage = nextStage;
  return replaceGraphics(name);
}

function hidePatch(name, nextStage) {
  state.stage = nextStage;
  return originalGraphics(name);
}

function revealLeech(advanceStage = false) {
  state.leechShown = true;
  if (advanceStage) {
    return showPatch('leech', 'done');
  }
  return replaceGraphics('leech');
}

function onTalk() {
  switch (state.stage) {
    case 'start':
      return say('She murmurs: bring me a flower.', 'need_flower');
    case 'need_flower':
      return say('She waits for the flower.');
    case 'flower_shown':
      return say('She takes it. Now bring her wine.', 'need_wine');
    case 'need_wine':
      return say('She wants a glass of wine.');
    case 'wine_shown':
      return hidePatch('wine', 'wine_hidden');
    case 'wine_hidden':
      return say('The glass is gone. Make her smile.', 'need_smile');
    case 'need_smile':
      return say('She still looks unimpressed.');
    case 'smile_shown':
      return say('Better. Give her a darker smile.', 'need_seducesmile');
    case 'need_seducesmile':
      return say('Not that smile. The dangerous one.');
    case 'seducesmile_shown':
      return say('Perfect. Now close her eyes.', 'need_closeeyes');
    case 'need_closeeyes':
      return say('She leans closer. Close her eyes.');
    case 'eyes_closed':
      return say('Now use the leech brain on her.', 'need_leech');
    case 'need_leech':
      return say('Do it. Use the leech brain.');
    case 'done':
      return say('The ritual is complete.');
    default:
      state.stage = 'start';
      return say('She watches you in silence.');
  }
}

function onFlower() {
  if (state.stage === 'need_flower') {
    return showPatch('flower', 'flower_shown');
  }
  if (state.stage === 'start') {
    return say('Talk to her first.');
  }
  return say('The flower is already hers.');
}

function onWine() {
  if (state.stage === 'need_wine') {
    return showPatch('wine', 'wine_shown');
  }
  if (state.stage === 'flower_shown') {
    return say('Hear what she asks first.');
  }
  if (state.stage === 'wine_shown') {
    return say('Give her a moment to drink.');
  }
  if (state.stage === 'wine_hidden' || state.stage === 'need_smile' || state.stage === 'smile_shown' || state.stage === 'need_seducesmile' || state.stage === 'seducesmile_shown' || state.stage === 'need_closeeyes' || state.stage === 'eyes_closed' || state.stage === 'need_leech' || state.stage === 'done') {
    return say('The empty glass is gone now.');
  }
  return say('She is not ready for wine yet.');
}

function onSmile() {
  if (state.stage === 'need_smile') {
    return showPatch('smile', 'smile_shown');
  }
  if (state.stage === 'need_seducesmile') {
    return showPatch('seducesmile', 'seducesmile_shown');
  }
  if (state.stage === 'smile_shown') {
    return say('Talk to her again.');
  }
  if (state.stage === 'seducesmile_shown' || state.stage === 'need_closeeyes' || state.stage === 'eyes_closed' || state.stage === 'need_leech' || state.stage === 'done') {
    return say('That simple smile is past.');
  }
  return say('You have not earned her smile yet.');
}

function onSeduceSmile() {
  if (state.stage === 'need_seducesmile') {
    return showPatch('seducesmile', 'seducesmile_shown');
  }
  if (state.stage === 'seducesmile_shown' || state.stage === 'need_closeeyes' || state.stage === 'eyes_closed' || state.stage === 'need_leech' || state.stage === 'done') {
    return say('She already wears that wicked smile.');
  }
  return say('Not yet. First make her truly smile.');
}

function onCloseEyes() {
  if (state.stage === 'need_closeeyes') {
    return showPatch('closeeyes', 'eyes_closed');
  }
  if (state.stage === 'eyes_closed' || state.stage === 'need_leech' || state.stage === 'done') {
    return say('Her eyes are already closed.');
  }
  return say('Not until she trusts you.');
}

function onLeech() {
  if (state.stage === 'need_leech') {
    return revealLeech(true);
  }
  if (!state.leechShown) {
    return revealLeech(false);
  }
  if (state.stage === 'done') {
    return say('The leech brain already did its work.');
  }
  return say('That would end badly if done too soon.');
}

if (!hit) {
  return null;
}

switch (hit.name) {
  case 'talk':
    return onTalk();
  case 'flower':
    return onFlower();
  case 'wine':
    return onWine();
  case 'smile':
    return onSmile();
  case 'seducesmile':
    return onSeduceSmile();
  case 'closeeyes':
    return onCloseEyes();
  case 'leech':
    return onLeech();
  default:
    return say('Nothing happens.');
}
