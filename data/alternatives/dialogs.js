const state = {
    stage: 'start',
    leechShown: false,
    currentDialog: 0,
    choices: []
};

function say(text, nextStage = state.stage, choices = []) {
    state.stage = nextStage;
    state.currentDialog = text;
    state.choices = choices;
    return displayDialog(text, choices);
}

function displayDialog(text, choices) {
    // Clear previous dialog
    clearDialog();

    // Display main dialog text
    displayText(text);

    // Display choices if any
    if (choices.length > 0) {
        displayChoices(choices);
    }

    return text;
}

function clearDialog() {
    // Clear dialog area
    clearText();
}

function displayChoices(choices) {
    // Display numbered choices
    choices.forEach((choice, index) => {
        displayText(`${index + 1}. ${choice.text}`);
    });
}

function handleChoice(choiceIndex) {
    if (state.choices[choiceIndex]) {
        const choice = state.choices[choiceIndex];
        return choice.action();
    }
    return say("Invalid choice. Please try again.");
}

// Dialog stages
function onTalk() {
    switch (state.stage) {
        case 'start':
            return say(
                "She looks at you with piercing eyes. 'What do you want?'",
                'start',
                [
                    { text: 'Introduce yourself', action: onIntroduce },
                    { text: 'Flirt with her', action: onFlirt },
                    { text: 'Ask about the leech', action: onAskLeech }
                ]
            );
        case 'need_flower':
            return say('She waits for the flower.', 'need_flower');
        case 'flower_shown':
            return say('She takes it. Now bring her wine.', 'need_wine');
        case 'need_wine':
            return say('She wants a glass of wine.', 'need_wine');
        case 'wine_shown':
            return hidePatch('wine', 'wine_hidden');
        case 'wine_hidden':
            return say('The glass is gone. Make her smile.', 'need_smile');
        case 'need_smile':
            return say('She still looks unimpressed.', 'need_smile');
        case 'smile_shown':
            return say('Better. Give her a darker smile.', 'need_seducesmile');
        case 'need_seducesmile':
            return say('Not that smile. The dangerous one.', 'need_seducesmile');
        case 'seducesmile_shown':
            return say('Perfect. Now close her eyes.', 'need_closeeyes');
        case 'need_closeeyes':
            return say('She leans closer. Close her eyes.', 'need_closeeyes');
        case 'eyes_closed':
            return say('Now use the leech brain on her.', 'need_leech');
        case 'need_leech':
            return say('Do it. Use the leech brain.', 'need_leech');
        case 'done':
            return say('The ritual is complete.');
        default:
            state.stage = 'start';
            return say('She watches you in silence.');
    }
}

function onIntroduce() {
    return say(
        "'I am [Your Name]. I seek knowledge and power.'",
        'start',
        [
            { text: 'Ask about her past', action: onAskPast },
            { text: 'Compliment her beauty', action: onCompliment },
            { text: 'Change the subject', action: onTalk }
        ]
    );
}

function onFlirt() {
    return say(
        "'You have a captivating presence. I can't look away.'",
        'start',
        [
            { text: 'Be more direct', action: onFlirtDirect },
            { text: 'Tell a joke', action: onTellJoke },
            { text: 'Back off', action: onTalk }
        ]
    );
}

function onAskLeech() {
    return say(
        "'What is the purpose of the leech brain?'",
        'start',
        [
            { text: 'Ask about the ritual', action: onAskRitual },
            { text: 'Express concern', action: onExpressConcern },
            { text: 'Demand answers', action: onDemandAnswers }
        ]
    );
}

function onAskPast() {
    return say(
        "'I have lived many lifetimes. My past is written in blood and shadows.'",
        'start',
        [
            { text: 'Ask for details', action: onAskDetails },
            { text: 'Express sympathy', action: onExpressSympathy },
            { text: 'Change the subject', action: onTalk }
        ]
    );
}

function onCompliment() {
    return say(
        "'Your beauty is as dangerous as it is alluring.'",
        'start',
        [
            { text: 'Be more specific', action: onBeSpecific },
            { text: 'Ask about her interests', action: onAskInterests },
            { text: 'Thank her', action: onTalk }
        ]
    );
}

function onFlirtDirect() {
    return say(
        "'I want to know every part of you. Your mind, your body, your soul.'",
        'start',
        [
            { text: 'Be even more direct', action: onBeEvenMoreDirect },
            { text: 'Tell a romantic story', action: onTellRomanticStory },
            { text: 'Back off', action: onTalk }
        ]
    );
}

function onTellJoke() {
    return say(
        "'Why did the vampire go to art school? To learn how to draw blood!'",
        'start',
        [
            { text: 'Tell another joke', action: onTellAnotherJoke },
            { text: 'Ask if she wants to hear more', action: onAskIfWantsMore },
            { text: 'Change the subject', action: onTalk }
        ]
    );
}

function onAskRitual() {
    return say(
        "'The ritual will bind our fates together. You will gain power beyond imagination.'",
        'start',
        [
            { text: 'Ask about the risks', action: onAskRisks },
            { text: 'Express excitement', action: onExpressExcitement },
            { text: 'Demand more information', action: onDemandMoreInfo }
        ]
    );
}

function onExpressConcern() {
    return say(
        "'I worry about the consequences. Is this truly what you want?'",
        'start',
        [
            { text: 'Ask about alternatives', action: onAskAlternatives },
            { text: 'Offer support', action: onOfferSupport },
            { text: 'Back off', action: onTalk }
        ]
    );
}

function onDemandAnswers() {
    return say(
        "'I need to know everything. No more secrets.'",
        'start',
        [
            { text: 'Threaten her', action: onThreaten },
            { text: 'Beg for answers', action: onBeg },
            { text: 'Back off', action: onTalk }
        ]
    );
}

function onAskDetails() {
    return say(
        "'My past is filled with betrayal, loss, and dark magic. I have seen empires rise and fall.'",
        'start',
        [
            { text: 'Ask about specific events', action: onAskSpecificEvents },
            { text: 'Express admiration', action: onExpressAdmiration },
            { text: 'Change the subject', action: onTalk }
        ]
    );
}

function onExpressSympathy() {
    return say(
        "'Your pain is evident. I wish I could ease your burden.'",
        'start',
        [
