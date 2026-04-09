// New Dialog-Based Game System
// Native server choice dialog system - fully compatible

const hit = roomSelections.find((selection) => {
    return x >= selection.x && x < selection.x + selection.width && y >= selection.y && y < selection.y + selection.height;
});

state.stage = typeof state.stage === 'string' ? state.stage : 'start';
state.leechShown = state.leechShown === true;
state.affection = state.affection || 0;
state.flirtCount = state.flirtCount || 0;

// Handle dialog choice selections first
if (clickedChoice) {
    switch(clickedChoice) {
        // Start stage choices
        case 'talk_normal':
            return say('She murmurs: bring me a flower.', 'need_flower');
        case 'flirt_1':
            state.affection += 5;
            state.flirtCount += 1;
            return say('A very faint smile touches her lips. Bring me a flower.', 'need_flower');
        case 'give_flower_early':
            return say('Talk to her first.');
        case 'stare':
            return say('She blinks slowly, but says nothing.');

        // Need flower choices
        case 'give_flower':
            return showPatch('flower', 'flower_shown');
        case 'flirt_2':
            state.affection += 10;
            state.flirtCount += 1;
            return say('Her cheeks color slightly. The flower. Please.');
        case 'ask_flower':
            return say('Any flower. As long as it is from you.');
        case 'offer_wine_early':
            return say('She shakes her head. First the flower.');

        // Flower shown choices
        case 'give_wine':
            return showPatch('wine', 'wine_shown');
        case 'flirt_3':
            state.affection += 10;
            state.flirtCount += 1;
            return say('Just the wine. For now.');
        case 'flirt_4':
            state.affection += 15;
            state.flirtCount += 1;
            return say('Her fingers brush yours for a moment before she takes the flower. Wine. Now.', 'flower_shown');
        case 'normal_response':
            return showPatch('wine', 'wine_shown');

        // Need wine choices
        case 'give_wine_2':
            return showPatch('wine', 'wine_shown');
        case 'flirt_5':
            state.affection += 10;
            state.flirtCount += 1;
            return say('Always. There is humor in her eyes.');
        case 'toast':
            return say('She nods once, waiting for you to hand her the glass.');
        case 'drink_first':
            return say('Dont be rude.');

        // Wine shown choices
        case 'make_smile':
            return showPatch('smile', 'smile_shown');
        case 'flirt_6':
            state.affection += 15;
            state.flirtCount += 1;
            return say('She laughs softly. Make me smile first, then we ll see about dreams.');
        case 'tell_joke':
            return say('She raises an eyebrow, unamused. Smile.');
        case 'smile_back':
            state.affection += 5;
            return say('Cute. Now make me smile.');

        // Need smile choices
        case 'make_smile_2':
            return showPatch('smile', 'smile_shown');
        case 'flirt_7':
            state.affection += 20;
            state.flirtCount += 1;
            return say('You already do. Just by being here. Now give me the smile.');
        case 'lean_close':
            state.affection += 10;
            return say('She doesnt pull away. Smile.');
        case 'whisper':
            state.affection += 15;
            return say('She shivers slightly. ...That works too. Now the smile.', 'smile_shown');

        // Smile shown choices
        case 'seduce_smile':
            return showPatch('seducesmile', 'seducesmile_shown');
        case 'flirt_8':
            state.affection += 15;
            state.flirtCount += 1;
            return say('For both of us. Now give it to me.');
        case 'flirt_9':
            state.affection += 20;
            state.flirtCount += 1;
            return say('She smirks. You have no idea. The dangerous smile please.');
        case 'wicked_grin':
            state.affection += 10;
            return showPatch('seducesmile', 'seducesmile_shown');

        // Need seduce smile choices
        case 'seduce_smile_2':
            return showPatch('seducesmile', 'seducesmile_shown');
        case 'flirt_10':
            state.affection += 25;
            state.flirtCount += 1;
            return say('Is it working?');
        case 'flirt_11':
            state.affection += 20;
            state.flirtCount += 1;
            return say('She smiles for you first, dangerously beautiful. Then you give hers back.', 'seducesmile_shown');
        case 'hold_gaze':
            state.affection += 15;
            return showPatch('seducesmile', 'seducesmile_shown');

        // Seduce smile shown choices
        case 'close_eyes':
            return showPatch('closeeyes', 'eyes_closed');
        case 'flirt_12':
            state.affection += 25;
            state.flirtCount += 1;
            return say('They wont be closed forever. Close them now.');
        case 'flirt_13':
            state.affection += 30;
            state.flirtCount += 1;
            return say('Her breath catches. ...Thank you. Now close them.');
        case 'brush_eyelids':
            state.affection += 20;
            return showPatch('closeeyes', 'eyes_closed');

        // Need close eyes choices
        case 'close_eyes_2':
            return showPatch('closeeyes', 'eyes_closed');
        case 'flirt_14':
            state.affection += 35;
            state.flirtCount += 1;
            return say('She kisses you softly, quickly. Now close my eyes.');
        case 'pause_close':
            state.affection += 20;
            return showPatch('closeeyes', 'eyes_closed');

        // Eyes closed choices
        case 'use_leech':
            return revealLeech(true);
        case 'flirt_15':
            state.affection += 30;
            state.flirtCount += 1;
            return say('You won\'t. Trust me.');
        case 'ask_what':
            return say('Something wonderful. Now do it.');
        case 'kiss_forehead':
            state.affection += 40;
            state.flirtCount += 1;
            return say('She leans into your touch. Now.');

        // Need leech choices
        case 'use_leech_2':
            return revealLeech(true);
        case 'flirt_16':
            state.affection += 40;
            state.flirtCount += 1;
            return say('It doesn\'t have to. Now please.');
        case 'hold_hand':
            state.affection += 30;
            return say('She squeezes your hand. Do it.');
        case 'tell_care':
            state.affection += 50;
            state.flirtCount += 1;
            return say('I know. That\'s why this will work.');

        // Done stage choices
        case 'stay':
            return say('You sit with her in silence. The ritual is complete.');
        case 'kiss_cheek':
            return say('You kiss her cheek softly. She doesn\'t wake.');
        case 'leave':
            return say('You leave quietly. The ritual is done.');
        case 'restart':
            state.stage = 'start';
            state.affection = 0;
            state.flirtCount = 0;
            state.leechShown = false;
            return say('You start over. She looks at you quietly.');

        default:
            return say('Nothing happens.');
    }
}

// Helper functions
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

// Open dialog when clicking talk area
if (hit && hit.name === 'talk') {
    switch (state.stage) {
        case 'start':
            return displayChoices([
                choice('talk_normal', 'Talk to her politely'),
                choice('flirt_1', 'Smile and flirt with her'),
                choice('give_flower_early', 'Give her the flower now'),
                choice('stare', 'Just stare silently')
            ], { text: 'She looks at you quietly, waiting. What do you do?' });

        case 'need_flower':
            return displayChoices([
                choice('give_flower', 'Give her the flower'),
                choice('flirt_2', 'You\'re very beautiful when you ask nicely'),
                choice('ask_flower', 'What kind of flower do you like?'),
                choice('offer_wine_early', 'Hold out the wine instead')
            ], { text: 'Bring me a flower. she murmurs softly.' });

        case 'flower_shown':
            return displayChoices([
                choice('give_wine', 'Give her the wine'),
                choice('flirt_3', 'Anything else I can get you?'),
                choice('flirt_4', 'Touch her hand as you pass it'),
                choice('normal_response', 'You\'re welcome.')
            ], { text: 'She takes the flower gently. Good. Now bring me wine.' });

        case 'need_wine':
            return displayChoices([
                choice('give_wine_2', 'Hand her the wine'),
                choice('flirt_5', 'Do you always get what you want?'),
                choice('toast', 'Toast her silently'),
                choice('drink_first', 'Drink some yourself first')
            ], { text: 'She waits expectantly for the wine glass.' });

        case 'wine_shown':
        case 'wine_hidden':
        case 'need_smile':
            return displayChoices([
                choice('make_smile', 'Make her smile gently'),
                choice('flirt_6', 'I\'ve already seen you smile in my dreams'),
                choice('tell_joke', 'Tell her a joke'),
                choice('smile_back', 'Smile back at her')
            ], { text: 'She takes the glass. Make me smile.' });

        case 'smile_shown':
            return displayChoices([
                choice('seduce_smile', 'Give her the seductive smile'),
                choice('flirt_8', 'Dangerous? For who?'),
                choice('flirt_9', 'You already look dangerous enough'),
                choice('wicked_grin', 'Show her your most wicked grin')
            ], { text: 'Better. Now give me a darker smile. The dangerous one.' });

        case 'need_seducesmile':
            return displayChoices([
                choice('seduce_smile_2', 'Give her the seductive smile'),
                choice('flirt_10', 'Are you trying to seduce me?'),
                choice('flirt_11', 'Only if you smile back first'),
                choice('hold_gaze', 'Hold her gaze')
            ], { text: 'She leans forward slightly. That dangerous smile. You know the one.' });

        case 'seducesmile_shown':
            return displayChoices([
                choice('close_eyes', 'Gently close her eyes'),
                choice('flirt_12', 'I\'d rather keep looking at them'),
                choice('flirt_13', 'They\'re beautiful closed or open'),
                choice('brush_eyelids', 'Brush your fingers against her eyelids')
            ], { text: 'She matches your smile perfectly. Perfect. Now close my eyes.' });

        case 'need_closeeyes':
            return displayChoices([
                choice('close_eyes_2', 'Close her eyes softly'),
                choice('flirt_14', 'Not until you kiss me first'),
                choice('pause_close', 'Pause, very close to her'),
                choice('close_eyes_2', 'Do as she asks')
            ], { text: 'She leans closer. You can feel her breath. Close my eyes.' });

        case 'eyes_closed':
            return displayChoices([
                choice('use_leech', 'Use the leech brain'),
                choice('flirt_15', 'I don\'t want to hurt you'),
                choice('ask_what', 'What will happen to you?'),
                choice('kiss_forehead', 'Kiss her forehead softly')
            ], { text: 'Her breathing slows. Now. Use the leech brain on me.' });

        case 'need_leech':
            return displayChoices([
                choice('use_leech_2', 'Complete the ritual'),
                choice('flirt_16', 'I don\'t want this to end'),
                choice('hold_hand', 'Hold her hand'),
                choice('tell_care', 'Tell her you care')
            ], { text: 'Do it. Her voice is barely a whisper.' });

        case 'done':
            return displayChoices([
                choice('stay', 'Stay with her'),
                choice('kiss_cheek', 'Kiss her cheek'),
                choice('leave', 'Leave quietly'),
                choice('restart', 'Start over')
            ], { text: 'The ritual is complete. She lies still, at peace.' });

        default:
            state.stage = 'start';
            return displayChoices([
                choice('restart', 'Begin again')
            ], { text: 'She watches you in silence.' });
    }
}

// Other clicks tell user to talk
if (hit && hit.name !== 'talk') {
    return say('Click on her to open dialog first.');
}

return null;
