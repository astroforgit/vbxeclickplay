const hit = roomSelections.find((selection) => {
    return x >= selection.x && x < selection.x + selection.width && y >= selection.y && y < selection.y + selection.height;
});

const LEGACY_STAGE_MAP = {
    start: 'intro',
    need_flower: 'await_flower',
    flower_shown: 'flower_shown',
    need_wine: 'await_wine',
    wine_shown: 'wine_shown',
    wine_hidden: 'wine_shown',
    need_smile: 'await_smile',
    smile_shown: 'smile_shown',
    need_seducesmile: 'await_seduce',
    seducesmile_shown: 'seduce_shown',
    need_closeeyes: 'await_eyes',
    eyes_closed: 'eyes_closed',
    need_leech: 'need_leech',
    done: 'ritual_done'
};

const STAGES = [
    'intro', 'await_flower', 'flower_shown', 'await_wine', 'wine_shown',
    'await_smile', 'smile_shown', 'await_seduce', 'seduce_shown',
    'await_eyes', 'eyes_closed', 'need_leech', 'ritual_done'
];

state.stage = LEGACY_STAGE_MAP[state.stage] || state.stage || 'intro';
if (STAGES.indexOf(state.stage) < 0) state.stage = 'intro';
state.affection = typeof state.affection === 'number' ? state.affection : 0;
state.flirtCount = typeof state.flirtCount === 'number' ? state.flirtCount : 0;
state.leechShown = state.leechShown === true;
state.epilogue = typeof state.epilogue === 'string' ? state.epilogue : '';

function menu(prompt, entries) {
    return displayChoices(entries.map(([id, text]) => choice(id, text)), { text: prompt });
}

function popup(text) {
    return displayText(text);
}

function story(text, nextStage = state.stage, options = {}) {
    state.stage = nextStage;
    if (options.affection) state.affection += options.affection;
    if (options.flirt) state.flirtCount += options.flirt;
    if (options.epilogue) state.epilogue = options.epilogue;
    return displayBottomText(text);
}

function reveal(name, nextStage) {
    state.stage = nextStage;
    if (name === 'leech') state.leechShown = true;
    return replaceGraphics(name);
}

function restartStory() {
    state.stage = 'intro';
    state.affection = 0;
    state.flirtCount = 0;
    state.leechShown = false;
    state.epilogue = '';
    return changeRoom('first');
}

function stageAtLeast(name) {
    return STAGES.indexOf(state.stage) >= STAGES.indexOf(name);
}

function endingText(kind) {
    const tender = state.affection >= 7 || state.flirtCount >= 4;
    if (kind === 'stay') {
        return tender
            ? 'You stay beside her until the candles gutter out. Just before dawn, her fingers close weakly around yours and her breathing steadies into something human again. The ritual takes its price, but it leaves her with enough warmth to remember your name.'
            : 'You stay until the wax hardens and the room forgets how to breathe. She never truly wakes, yet the terrible pressure in the walls lifts, as if some old hunger has been fed at last. When morning comes, you know the ritual changed both of you.';
    }
    if (kind === 'kiss') {
        return tender
            ? 'You kiss her cheek and feel the faintest answer in the corner of her mouth. For one suspended second the dangerous woman is gone, replaced by someone tired, grateful, and still alive enough to lean toward you even in sleep.'
            : 'Your kiss lands on skin cold as porcelain. The silver bowl cracks with a tiny sound somewhere behind you, and the silence that follows feels less like peace than a vow you have just been forced to keep.';
    }
    return tender
        ? 'You leave only after pulling the shawl higher across her shoulders. Outside, dawn looks softer than it did before you entered. Whatever happened in that room was not mercy exactly, but it was not empty either.'
        : 'You leave before dawn can touch the windows. The corridor behind you stays dark, and for days afterward you can still taste iron and wine when you wake. Some doors close quietly. That does not mean they are harmless.';
}

function inspectSelection(name) {
    switch (name) {
        case 'flower':
            if (state.stage === 'await_flower') return reveal('flower', 'flower_shown');
            return stageAtLeast('flower_shown')
                ? popup('The flower is already in her hand.')
                : popup('A pale flower waits in a chipped vase.');
        case 'wine':
            if (state.stage === 'await_wine') return reveal('wine', 'wine_shown');
            return stageAtLeast('wine_shown')
                ? popup('The dark wine already glows in the glass.')
                : popup('Dark wine rests in a thin crystal glass.');
        case 'smile':
            if (state.stage === 'await_smile') return reveal('smile', 'smile_shown');
            return stageAtLeast('smile_shown')
                ? popup('Her gentler smile is already there.')
                : popup('A softer smile waits beneath her calm face.');
        case 'seducesmile':
            if (state.stage === 'await_seduce') return reveal('seducesmile', 'seduce_shown');
            return stageAtLeast('seduce_shown')
                ? popup('That dangerous smile already owns the room.')
                : popup('That smile looks like a promise and a threat.');
        case 'closeeyes':
            if (state.stage === 'await_eyes') return reveal('closeeyes', 'eyes_closed');
            return stageAtLeast('eyes_closed')
                ? popup('Her lashes rest against her cheeks now.')
                : popup('Not yet. She still wants to watch you.');
        case 'leech':
            if (state.stage === 'need_leech') return reveal('leech', 'ritual_done');
            return state.leechShown
                ? popup('The leech brain has already done its work.')
                : popup('The preserved leech brain twitches faintly in its bowl.');
        default:
            return popup('There is something here, but not for this moment.');
    }
}

const choiceHandlers = {
    intro_greet: () => story(
        'You give her your name. She lets it hang in the air between you, then glances to the pale bloom on the table. Names are easy, she murmurs. Offer me the flower if you want the night to keep opening.',
        'await_flower'
    ),
    intro_flirt: () => story(
        'Bold already? The question should sting, but the corner of her mouth softens instead. Then prove you can be gentle too. Bring me the flower first, she says, and maybe I will answer beauty with beauty.',
        'await_flower',
        { affection: 2, flirt: 1 }
    ),
    intro_ritual: () => story(
        'She studies you for so long that the room itself seems to lean closer. Old doors do not open to force, she says at last. They open to offerings. Start with the flower, and I will tell you what waits after it.',
        'await_flower'
    ),
    intro_silent: () => popup('She waits for words, not silence.'),

    flower_question: () => story(
        'The flower carries memory better than blood, she says. Scent reaches places reason cannot. Tonight I need memory to come willingly, not screaming. Bring it to me.',
        'await_flower'
    ),
    flower_flirt: () => story(
        'You tell her the flower already belongs beside her mouth. This time the smile does not quite disappear. Careful, she whispers. Keep talking like that and I may start believing you.',
        'await_flower',
        { affection: 1, flirt: 1 }
    ),
    flower_obey: () => popup('Then place the flower in her hand.'),
    flower_stall: () => popup('She tilts her head. The flower first.'),

    after_flower_next: () => story(
        'She lifts the flower beneath her nose and closes her eyes for a heartbeat. Better, she says. Now bring the wine. Blood remembers, but wine persuades. I need both memory and surrender before the last part begins.',
        'await_wine'
    ),
    after_flower_hand: () => story(
        'Your fingers linger against hers as she takes the bloom. She notices; of course she notices. Good, she murmurs, not pulling away. Keep that courage. Bring me the wine before it fades.',
        'await_wine',
        { affection: 2, flirt: 1 }
    ),
    after_flower_watch: () => story(
        'You watch her breathe in the scent. The room seems to settle around that small gesture. She opens her eyes again and there is less distance in them now. Wine next, she says quietly. Dark, slow, and honest.',
        'await_wine'
    ),
    after_flower_joke: () => story(
        'You tell her that a flower should have earned you at least one smile. It earns you half of one. Half is all you get for free, she says. If you want the rest, bring the wine.',
        'await_wine',
        { affection: 1, flirt: 1 }
    ),

    wine_question: () => story(
        'Wine loosens the shape of fear, she says. It lets the body agree to things the mind would spend all night refusing. Bring it here. I would rather not refuse what comes next.',
        'await_wine'
    ),
    wine_toast: () => story(
        'You promise her a private toast once the glass is in her hand. Her gaze warms by a single degree. Then make good on it, she says. Bring me the wine before the moment spoils.',
        'await_wine',
        { affection: 1 }
    ),
    wine_tease: () => story(
        'You accuse her of liking the sound of giving orders. She almost laughs. Only when the orders are obeyed, she says. The glass is right there. Do not ruin your argument now.',
        'await_wine',
        { affection: 1, flirt: 1 }
    ),
    wine_offer: () => popup('Then hand her the wine.'),

    after_wine_smile: () => story(
        'She drinks slowly. When the glass lowers, her voice has gone velvet-soft. Now make me smile, she says. A real smile, not the careful one you wear for daylight. I want the one you only trust to darkness.',
        'await_smile'
    ),
    after_wine_flirt: () => story(
        'You tell her the wine envies her lips. This time she does laugh, low and brief and dangerous. Then earn another one, she says. Make me smile for real.',
        'await_smile',
        { affection: 2, flirt: 1 }
    ),
    after_wine_confess: () => story(
        'You admit that you are already too deep in this to pretend otherwise. Good, she answers. Depth matters. So does trust. Start by making me smile, and we will see how far down you can follow me.',
        'await_smile',
        { affection: 1 }
    ),
    after_wine_listen: () => story(
        'You say nothing and simply stay close enough to hear her breathe between sips. When she finally looks back at you, there is approval in it. Now the smile, she whispers. The gentle one first.',
        'await_smile'
    ),

    smile_question: () => story(
        'Not every smile means the same thing, she says. I want the one that chooses me, not the one that performs for the room. Show me that you understand the difference.',
        'await_smile'
    ),
    smile_flirt: () => story(
        'You tell her that the room has been waiting all evening to see her smile. A softness passes over her face that has nothing to do with the candles. Then draw it out of me, she says.',
        'await_smile',
        { affection: 1, flirt: 1 }
    ),
    smile_reach: () => popup('Then touch the gentler smile.'),
    smile_wait: () => popup('She waits for you to coax the smile free.'),

    after_smile_more: () => story(
        'Better, she says, and the gentle smile fades before you can get used to it. But not enough. I want the smile that knows how to ruin a life and enjoy it. Give me that one next.',
        'await_seduce'
    ),
    after_smile_flirt: () => story(
        'You tell her the room changed the moment she smiled. It did, she agrees. Now change it again. Give me the darker smile, the one that would make a saint stay anyway.',
        'await_seduce',
        { affection: 2, flirt: 1 }
    ),
    after_smile_whisper: () => story(
        'You lean close enough to whisper that she looks dangerous now. Finally, she says, sounding pleased. So show me you can match it. Give me the dangerous smile back.',
        'await_seduce',
        { affection: 1, flirt: 1 }
    ),
    after_smile_hold: () => story(
        'You try to hold the moment still, but she is already reaching past it. Do not fall in love with the safe version of me, she says softly. Give me the darker smile.',
        'await_seduce'
    ),

    seduce_question: () => story(
        'Because sight keeps people honest, she says. What comes next asks for something stranger than honesty. Close my eyes when the room is ready, and maybe yours will open instead.',
        'await_eyes'
    ),
    seduce_trust: () => story(
        'You tell her to trust you. She considers that longer than any flirtation deserved, then nods once. Good. Then prove you mean it. Close my eyes for me.',
        'await_eyes',
        { affection: 1 }
    ),
    seduce_dare: () => story(
        'You say you are not afraid of her. Her answer is almost tender. Not of me, perhaps. But fear is not done with us tonight. Close my eyes and let us find out what remains.',
        'await_eyes',
        { affection: 1, flirt: 1 }
    ),
    seduce_touch: () => popup('Then close her eyes gently.'),

    eyes_next: () => story(
        'With her eyes closed, every word sounds more intimate. In the silver bowl is the last instrument, she whispers. The leech brain remembers hunger, direction, and return. Use it, and the ritual will finally choose its shape.',
        'need_leech'
    ),
    eyes_hold: () => story(
        'You take her hand before she can ask. Her fingers tighten around yours as though she expected you to run. Stay until the end, she whispers. Then use what waits in the bowl.',
        'need_leech',
        { affection: 2 }
    ),
    eyes_kiss: () => story(
        'You kiss her forehead and feel her lean into it, small and involuntary. There you are, she breathes. Now do the last thing. Take the leech brain and finish it before I lose my nerve.',
        'need_leech',
        { affection: 2, flirt: 1 }
    ),
    eyes_doubt: () => story(
        'You admit that you are afraid. Good, she says immediately. Fear means you still understand the cost. Do it anyway. Take the leech brain before courage curdles into regret.',
        'need_leech'
    ),

    leech_stay: () => story(
        'You promise that you will stay beside her, no matter what the ritual asks back. Her grip loosens, trusting you at last. Then do it, she whispers. I would rather cross with you here than alone.',
        'need_leech',
        { affection: 2 }
    ),
    leech_goodbye: () => story(
        'Is this goodbye? you ask. Not goodbye, she says. A threshold. The kind people only survive when someone is willing to witness them. Please. Use it now.',
        'need_leech'
    ),
    leech_care: () => story(
        'You tell her that this stopped being curiosity a long time ago. I know, she says, and the words sound relieved. That is why it might work. Finish it.',
        'need_leech',
        { affection: 2, flirt: 1 }
    ),
    leech_reach: () => popup('Then take the leech brain from the bowl.'),

    end_stay: () => story(endingText('stay'), 'ritual_done', { epilogue: 'stay' }),
    end_kiss: () => story(endingText('kiss'), 'ritual_done', { epilogue: 'kiss' }),
    end_leave: () => story(endingText('leave'), 'ritual_done', { epilogue: 'leave' }),
    end_restart: () => restartStory()
};

function handleTalk() {
    switch (state.stage) {
        case 'intro':
            return menu('She waits for your first move.', [
                ['intro_greet', 'Introduce yourself'],
                ['intro_flirt', 'Tell her she is beautiful'],
                ['intro_ritual', 'Ask about the ritual'],
                ['intro_silent', 'Keep staring at her']
            ]);
        case 'await_flower':
            return menu('She wants the flower first.', [
                ['flower_question', 'Ask why the flower matters'],
                ['flower_flirt', 'Say it suits her already'],
                ['flower_obey', 'Reach for the flower'],
                ['flower_stall', 'Ask for more time']
            ]);
        case 'flower_shown':
            return menu('She turns the flower slowly.', [
                ['after_flower_next', 'Ask what comes next'],
                ['after_flower_hand', 'Let your fingers linger'],
                ['after_flower_watch', 'Watch her smell the petals'],
                ['after_flower_joke', 'Say she owes you a smile']
            ]);
        case 'await_wine':
            return menu('The dark wine waits nearby.', [
                ['wine_question', 'Ask why the wine matters'],
                ['wine_toast', 'Promise her a private toast'],
                ['wine_tease', 'Say she likes ordering you'],
                ['wine_offer', 'Reach for the glass']
            ]);
        case 'wine_shown':
            return menu('The wine deepens her voice.', [
                ['after_wine_smile', 'Ask what she wants now'],
                ['after_wine_flirt', 'Say the wine envies her lips'],
                ['after_wine_confess', 'Admit you are in too deep'],
                ['after_wine_listen', 'Just listen to her breathe']
            ]);
        case 'await_smile':
            return menu('She wants a real smile now.', [
                ['smile_question', 'Ask what smile she means'],
                ['smile_flirt', 'Tell her the room is waiting'],
                ['smile_reach', 'Reach toward her mouth'],
                ['smile_wait', 'Let the silence gather']
            ]);
        case 'smile_shown':
            return menu('Her gentler smile appears.', [
                ['after_smile_more', 'Ask for the darker one'],
                ['after_smile_flirt', 'Say the room changed with it'],
                ['after_smile_whisper', 'Call her dangerous'],
                ['after_smile_hold', 'Try to hold the moment']
            ]);
        case 'await_seduce':
            return menu('She wants the dangerous smile.', [
                ['seduce_question', 'Ask why she wants it'],
                ['seduce_trust', 'Tell her to trust you'],
                ['seduce_dare', 'Say you are not afraid'],
                ['seduce_touch', 'Lift a hand toward her face']
            ]);
        case 'seduce_shown':
            return menu('Now she looks almost cruel.', [
                ['seduce_question', 'Ask why her eyes must close'],
                ['seduce_trust', 'Promise you will be gentle'],
                ['seduce_dare', 'Say you still want her'],
                ['seduce_touch', 'Close her eyes for her']
            ]);
        case 'await_eyes':
            return menu('Her eyes are still on you.', [
                ['seduce_trust', 'Tell her to trust you'],
                ['seduce_dare', 'Say you are ready'],
                ['seduce_touch', 'Reach toward her lashes'],
                ['seduce_question', 'Ask what comes after']
            ]);
        case 'eyes_closed':
            return menu('Her eyes are closed. She listens.', [
                ['eyes_next', 'Ask what happens now'],
                ['eyes_hold', 'Take her hand'],
                ['eyes_kiss', 'Kiss her forehead'],
                ['eyes_doubt', 'Admit you are afraid']
            ]);
        case 'need_leech':
            return menu('The silver bowl waits by her hand.', [
                ['leech_stay', 'Promise you will stay'],
                ['leech_goodbye', 'Ask if this is goodbye'],
                ['leech_care', 'Tell her you care'],
                ['leech_reach', 'Reach for the bowl']
            ]);
        case 'ritual_done':
            return menu('The ritual is finished. And now?', [
                ['end_stay', 'Stay with her'],
                ['end_kiss', 'Kiss her cheek'],
                ['end_leave', 'Leave quietly'],
                ['end_restart', 'Start over']
            ]);
        default:
            state.stage = 'intro';
            return handleTalk();
    }
}

if (clickedChoice) {
    if (choiceHandlers[clickedChoice]) {
        return choiceHandlers[clickedChoice]();
    }
    return popup('That choice no longer belongs to this moment.');
}

if (hit) {
    if (hit.name === 'talk') {
        return handleTalk();
    }
    return inspectSelection(hit.name);
}

return null;
