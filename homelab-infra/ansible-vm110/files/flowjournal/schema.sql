-- Flow Journal Database Schema
-- PostgreSQL 14+

-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    intro_completed BOOLEAN DEFAULT FALSE
);

-- Initial 7-question reflection
CREATE TABLE intro_reflection (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) UNIQUE,
    q1_important_events TEXT,
    q2_current_thoughts TEXT,
    q3_physical_symptoms TEXT,
    q4_current_feelings TEXT,
    q5_brought_closer TEXT,
    q6_brought_further TEXT,
    q7_change_in_10_weeks TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Daily journal entries
CREATE TABLE daily_entries (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    entry_date DATE NOT NULL,
    
    -- Daily energy level (1-10)
    energy_level INTEGER CHECK (energy_level >= 1 AND energy_level <= 10),
    
    -- Section 1: Hogyan érzem magam?
    selected_emotions TEXT[],
    how_want_to_feel TEXT,
    daily_mantra TEXT,
    
    -- Section 2: Gratitude & Goals
    grateful_1 TEXT,
    grateful_2 TEXT,
    grateful_3 TEXT,
    goal_1 TEXT,
    goal_2 TEXT,
    goal_3 TEXT,
    
    -- Section 3: Öngondoskodás
    selfcare_actions TEXT,
    free_journal TEXT,
    favorite_moment TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(user_id, entry_date)
);

-- User settings (customizable emotions and wheel)
CREATE TABLE user_settings (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) UNIQUE,
    
    -- 3-layer emotion wheel structure
    emotion_wheel JSONB DEFAULT '{
        "ÖRÖM": {
            "color": "#FFB366",
            "secondary": {
                "BIZTONSÁG": ["SZERETETT", "TISZTELET", "MEGÉRTETT"],
                "BÉKÉS": ["ELÉGEDETT", "NYUGODT", "FELSZABADULT"],
                "ELÉGEDETT": ["TÜRELMES", "KIEGYENSÚLYOZOTT", "GONDTALAN"],
                "BÜSZKE": ["ÉRTÉKES", "SIKERES", "JELENTŐS"],
                "NYITOTT": ["JÁTÉKOS", "KÍVÁNCSI", "LELKES"],
                "ENERGIKUS": ["IZGATOTT", "LENDÜLETES", "FELPÖRGETETT"],
                "LELKESEDETT": ["INSPIRÁLT", "KREATÍV", "SZENVEDÉLYES"]
            }
        },
        "UNDOR": {
            "color": "#D4CFC9",
            "secondary": {
                "KÉTELKEDÉS": ["GYANAKVÓ", "ÓVATOS", "BIZALMATLAN"],
                "BŰNBÁNAT": ["SZÉGYENKEZÕ", "ELUTASÍTÓ", "UNDORÍTÓ"],
                "LEHANGOLT": ["SZOMORÚ", "LEVERT", "NYOMOTT"],
                "MEGBÁNTOTT": ["ELUTASÍTOTT", "CSALÓDOTT", "MEGALÁZOTT"],
                "KRITIZÁLÓ": ["ELÍTÉLÕ", "LENÉZÕ", "GÕGÖS"]
            }
        },
        "HARAG": {
            "color": "#FFB366",
            "secondary": {
                "SÉRTETT": ["MEGVETETT", "LENÉZETT", "TISZTELETLENNEK ÉRZETT"],
                "DÜHÖS": ["MÉRGES", "ELLENSÉGES", "BOSSZÚÁLLÓ"],
                "FRUSZTRÁLT": ["INGERÜLT", "TÜRELMETLEN", "IDEGES"],
                "ZAKLATOZOTT": ["NYUGTALAN", "FESZÜLT", "ÉRZÉKENY"],
                "IRRITÁLT": ["BOSSZÚS", "BOSSZANTOTT", "ELLENÁLLÓ"]
            }
        },
        "SZOMORÚSÁG": {
            "color": "#C8CDD4",
            "secondary": {
                "CSÜGGEDT": ["KILÁTÁSTALAN", "LETÖRT", "REMÉNYTELEN"],
                "DEPRIMÁLT": ["ÜRES", "KIÁBRÁNDULT", "ELVESZETT"],
                "MAGÁNYOS": ["ELHAGYATOTT", "ELSZIGETELT", "ELVÁLASZTOTT"],
                "KÉTSÉGBEESETT": ["KESERVES", "SZÁNALMAS", "BOLDOGTALAN"],
                "TEHETETLEN": ["GYENGE", "TÖRÉKENY", "SZERENCSÉTLEN"],
                "BŰNÖS": ["MEGBÁNÓ", "SZÉGYENKEZÕ", "ROSSZ"],
                "VÉTKESNEK ÉRZI": ["FELELÕS", "ÁRULÓ", "BŰNÖS"]
            }
        },
        "FÉLELEM": {
            "color": "#E8DDD0",
            "secondary": {
                "RÉMÜLT": ["SOKKOLT", "MEGDÖBBENT", "PÁNIKOLT"],
                "RIADT": ["AGGÓDÓ", "IJEDT", "IZGATOTT"],
                "FÉLÉNK": ["SZORONG", "KÉTKEDÕ", "AGGÓDÓ"],
                "STRESSZES": ["TÚLTERHELT", "NYOMOTT", "FESZÜLT"],
                "ELFOJTOTT": ["GÁTOLT", "VISSZATARTOTT", "BLOKOLT"],
                "UNOTT": ["KÖZÖMBÖS", "ÉRDEKTELEN", "APÁTIKUS"]
            }
        },
        "MEGLEPETTSÉG": {
            "color": "#E8DDD0",
            "secondary": {
                "ZAVAROS": ["MEGLEPETT", "ELBIZONYTALANODOTT", "DÖBBENT"],
                "BIZONYTALLAN": ["KÉTSÉGEK", "BIZONYTALAN", "INGADOZÓ"],
                "IZGATOTT": ["VÁRAKOZÓ", "KÍVÁNCSI", "FESZÜLT"]
            }
        }
    }'::jsonb,
    
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Weekly and end reflections (for future phases)
CREATE TABLE reflections (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    reflection_type VARCHAR(20), -- 'weekly', 'end'
    period_start DATE,
    period_end DATE,
    data JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Weekly reflections (every 7 days)
CREATE TABLE weekly_reflections (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    week_number INTEGER NOT NULL,
    week_start_date DATE NOT NULL,
    week_end_date DATE NOT NULL,
    
    -- Q0: Mood selection
    current_mood VARCHAR(20), -- 'angry', 'sad', 'sleepy', 'balanced', 'king'
    
    -- Q1: Important results (4 lines)
    important_results TEXT,
    
    -- Q2: Important realizations (3 lines)
    important_realizations TEXT,
    
    -- Q3: Proud of myself because (5 items)
    proud_1 TEXT,
    proud_2 TEXT,
    proud_3 TEXT,
    proud_4 TEXT,
    proud_5 TEXT,
    
    -- Q4: Change journey phase
    change_phase VARCHAR(20), -- 'elutasitas', 'ellenallas', 'fordulopont', 'elfogadas', 'elkotelezes'
    change_reflection TEXT,
    
    -- Q5: Next week focus (1 line)
    next_week_focus TEXT,
    
    -- Q6: Most important tasks (5 items)
    task_1 TEXT,
    task_2 TEXT,
    task_3 TEXT,
    task_4 TEXT,
    task_5 TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, week_number)
);

-- Final reflection (after 70 days)
CREATE TABLE final_reflection (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) UNIQUE,
    
    -- Q1: Where did I start? (6 lines)
    q1_starting_point TEXT,
    
    -- Q2: How did I feel during 70 days? What was my goal? (6 lines)
    q2_feeling_and_goal TEXT,
    
    -- Q3: What happened to me? Obstacles, events, changes (6 lines)
    q3_journey_obstacles TEXT,
    
    -- Q4: Where did I arrive? What changed? (7 lines)
    q4_arrival_changes TEXT,
    
    -- Q5: What did I learn about myself? (7 lines)
    q5_self_learning TEXT,
    
    -- Q6: Where does the road lead? Next step? (6 lines)
    q6_future_path TEXT,
    
    -- Q7: Impact of journaling habit (11 lines)
    q7_journaling_impact TEXT,
    
    -- Q8: How will I celebrate? (35 lines)
    q8_celebration TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_daily_entries_user_date ON daily_entries(user_id, entry_date DESC);
CREATE INDEX idx_weekly_reflections_user_week ON weekly_reflections(user_id, week_number DESC);
CREATE INDEX idx_reflections_user_type ON reflections(user_id, reflection_type);
