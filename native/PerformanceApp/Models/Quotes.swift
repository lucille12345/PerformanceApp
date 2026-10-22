import Foundation

struct Fuel: Hashable {
    enum Kind: String { case quote = "QUOTE", fact = "FACT" }
    var kind: Kind
    var text: String
    var source: String
}

enum Quotes {
    /// One per app day, cycling through the list.
    static func forDay(_ day: Date) -> Fuel {
        let n = Days.calendar.ordinality(of: .day, in: .era, for: day) ?? 0
        return all[n % all.count]
    }

    static let all: [Fuel] = [
        .init(kind: .fact, text: "It takes an average of 66 days of repetition before a new habit becomes automatic.", source: "Lally et al., University College London, 2009"),
        .init(kind: .quote, text: "You do not rise to the level of your goals. You fall to the level of your systems.", source: "James Clear, Atomic Habits"),
        .init(kind: .quote, text: "The impediment to action advances action. What stands in the way becomes the way.", source: "Marcus Aurelius, Meditations"),
        .init(kind: .fact, text: "Just having your phone on the desk — even face down and switched off — measurably reduces your working memory and focus.", source: "Ward et al., Journal of the Association for Consumer Research, 2017"),
        .init(kind: .quote, text: "Hard work beats talent when talent doesn't work hard.", source: "Tim Notke"),
        .init(kind: .quote, text: "All of humanity's problems stem from man's inability to sit quietly in a room alone.", source: "Blaise Pascal, Pensées"),
        .init(kind: .fact, text: "After an interruption, it takes on average about 23 minutes to fully get back to the original task.", source: "Gloria Mark, University of California, Irvine"),
        .init(kind: .quote, text: "Pressure is a privilege.", source: "Billie Jean King"),
        .init(kind: .quote, text: "Fall seven times, stand up eight.", source: "Japanese proverb"),
        .init(kind: .fact, text: "People who wrote down exactly when and where they would exercise were 91% likely to do it, against 35–38% for those who didn't.", source: "Milne, Orbell & Sheeran, 2002"),
        .init(kind: .quote, text: "He who has a why to live can bear almost any how.", source: "Friedrich Nietzsche"),
        .init(kind: .quote, text: "Inspiration is for amateurs — the rest of us just show up and get to work.", source: "Chuck Close"),
        .init(kind: .fact, text: "Two weeks of sleeping 6 hours a night impairs performance as much as a full night without sleep — and people barely notice it.", source: "Van Dongen et al., Sleep, 2003"),
        .init(kind: .quote, text: "We suffer more often in imagination than in reality.", source: "Seneca, Letters to Lucilius"),
        .init(kind: .quote, text: "I hated every minute of training, but I said, don't quit. Suffer now and live the rest of your life as a champion.", source: "Muhammad Ali"),
        .init(kind: .fact, text: "Testing yourself on material beats re-reading it: students who practised recall remembered far more a week later.", source: "Roediger & Karpicke, Psychological Science, 2006"),
        .init(kind: .quote, text: "We are what we repeatedly do. Excellence, then, is not an act, but a habit.", source: "Will Durant, on Aristotle"),
        .init(kind: .quote, text: "Discipline is the bridge between goals and accomplishment.", source: "Jim Rohn"),
        .init(kind: .fact, text: "Switching between tasks can cost up to 40% of your productive time.", source: "American Psychological Association, after Rubinstein, Meyer & Evans, 2001"),
        .init(kind: .quote, text: "I am not afraid of storms, for I am learning how to sail my ship.", source: "Louisa May Alcott, Little Women"),
        .init(kind: .quote, text: "Our greatest glory is not in never falling, but in rising every time we fall.", source: "Oliver Goldsmith"),
        .init(kind: .fact, text: "In one study, most men chose to give themselves electric shocks rather than sit alone with their thoughts for 15 minutes. Learn to be comfortable alone.", source: "Wilson et al., Science, 2014"),
        .init(kind: .quote, text: "Everybody has a plan until they get punched in the mouth.", source: "Mike Tyson"),
        .init(kind: .quote, text: "Well done is better than well said.", source: "Benjamin Franklin"),
        .init(kind: .fact, text: "A year of regular aerobic exercise grew the brain's memory centre, the hippocampus, by about 2%.", source: "Erickson et al., PNAS, 2011"),
        .init(kind: .quote, text: "Do what you can, with what you have, where you are.", source: "Theodore Roosevelt"),
        .init(kind: .quote, text: "It does not matter how slowly you go as long as you do not stop.", source: "Attributed to Confucius"),
        .init(kind: .fact, text: "Spacing your study sessions out over days beats cramming the same hours into one session.", source: "Cepeda et al., Psychological Bulletin, 2006"),
        .init(kind: .quote, text: "Talent is cheaper than table salt. What separates the talented individual from the successful one is a lot of hard work.", source: "Stephen King"),
        .init(kind: .quote, text: "Suffer the pain of discipline or suffer the pain of regret.", source: "Attributed to Jim Rohn"),
        .init(kind: .fact, text: "The best violinists had practised alone, deliberately, for around 10,000 hours by age 20 — thousands more than good ones.", source: "Ericsson, Krampe & Tesch-Römer, 1993"),
        .init(kind: .quote, text: "Embrace the suck.", source: "U.S. military saying"),
        .init(kind: .quote, text: "Motivation is what gets you started. Habit is what keeps you going.", source: "Jim Ryun"),
        .init(kind: .quote, text: "Whether you think you can, or you think you can't — you're right.", source: "Attributed to Henry Ford"),
        .init(kind: .quote, text: "Energy and persistence conquer all things.", source: "Benjamin Franklin"),
        .init(kind: .quote, text: "The successful warrior is the average man, with laser-like focus.", source: "Attributed to Bruce Lee"),
        .init(kind: .quote, text: "Don't count the days. Make the days count.", source: "Attributed to Muhammad Ali"),
        .init(kind: .quote, text: "The best time to plant a tree was 20 years ago. The second best time is now.", source: "Proverb"),
        .init(kind: .quote, text: "If you're going through hell, keep going.", source: "Attributed to Winston Churchill"),
        .init(kind: .quote, text: "A goal without a plan is just a wish.", source: "Attributed to Antoine de Saint-Exupéry"),
    ]
}
