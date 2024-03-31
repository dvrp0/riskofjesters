--- STEAMODDED HEADER
--- MOD_NAME: Risk of Jesters
--- MOD_ID: RiskofJesters
--- MOD_AUTHOR: [DVRP]
--- MOD_DESCRIPTION: Risk of Rain themed content pack

----------------------------------------------
------------MOD CODE -------------------------

function SMODS.INIT.RiskofJesters()
    _RELEASE_MODE = false
    local mod = SMODS.findModByID("RiskofJesters")
    local jokers = love.filesystem.load(mod.path.."jokers.lua")()
    local vouchers = love.filesystem.load(mod.path.."vouchers.lua")()
    local blinds = love.filesystem.load(mod.path.."blinds.lua")()

    local function apply_localization()
        local loc_en, loc_ko = love.filesystem.load(mod.path.."localizations.lua")()

        local function apply(target, source)
            for k, v in pairs(source) do
                if type(target[k]) == "table" then
                    apply(target[k], v)
                else
                    target[k] = v
                end
            end
        end

        apply(G.localization, G.LANG.key == "ko" and loc_ko or loc_en)
        init_localization()
    end

    local function inject_jokers()
        local order = table_length(G.P_CENTER_POOLS.Joker)

        for k, v in pairs(jokers) do
            v.order = v.order + order

            G.P_CENTERS[k] = v
            table.insert(G.P_CENTER_POOLS.Joker, v)
            table.insert(G.P_JOKER_RARITY_POOLS[v.rarity], v)
        end

        table.sort(G.P_CENTER_POOLS.Joker, function (a, b) return a.order < b.order end)
    end

    local function inject_vouchers()
        local order = table_length(G.P_CENTER_POOLS.Voucher)

        for k, v in pairs(vouchers) do
            v.order = v.order + order

            G.P_CENTERS[k] = v
            table.insert(G.P_CENTER_POOLS.Voucher, v)
        end
    end

    local function inject_blinds()
        local order = table_length(G.P_BLINDS)

        for k, v in pairs(blinds) do
            v.order = v.order + order

            G.P_BLINDS[k] = v
        end
    end

    -- Manually inject Jokers instead of Steamodded to fix some bugs and provide better localization
    for k, v in pairs(jokers) do
        SMODS.Sprite:new(k, mod.path, k..".png", 71, 95, "asset_atli"):register()

        v.key = k
        v.config = v.config or {}
        v.cost_mult = 1.0
        v.set = "Joker"
        v.pos = {x = 0, y = 0}
        v.atlas = k
    end

    for k, v in pairs(vouchers) do
        SMODS.Sprite:new(k, mod.path, k..".png", 71, 95, "asset_atli"):register()

        v.key = k
        v.config = v.config or {}
        v.available = true
        v.set = "Voucher"
        v.pos = {x = 0, y = 0}
        v.atlas = k
    end

    for k, v in pairs(blinds) do
        SMODS.Sprite:new(k, mod.path, k..".png", 34, 34, "animation_atli", 21):register()

        v.key = k
        v.defeated = false
        v.vars = v.vars or {}
        v.debuff = v.debuff or {}
        v.pos = {x = 0, y = 0}
        v.atlas = k
    end

    inject_jokers()
    inject_vouchers()
    inject_blinds()

    local main_menu_ref = Game.main_menu
    function Game:main_menu()
        apply_localization()

        for k, v in pairs(jokers) do
            if not SMODS.Jokers[k] then
                SMODS.Jokers[k] = v
            end
        end

        main_menu_ref(self)
    end

    local change_lang_ref = G.FUNCS.change_lang
    function G.FUNCS.change_lang(e)
        local lang = e.config.ref_table
        local reinject = lang and lang ~= G.LANG

        change_lang_ref(e)

        -- Injected contents are removed when language is changed, so reinject them
        if reinject then
            G.E_MANAGER:add_event(Event({
                trigger = "after",
                delay = 0.3,
                no_delete = true,
                blockable = true,
                blocking = false,
                func = function()
                    apply_localization()
                    inject_jokers()
                    inject_vouchers()
                    inject_blinds()

                    return true
                end
            }))
        end
    end
end

local attention_text_ref = attention_text
function attention_text(args)
    attention_text_ref(args)

    if args.text and args.text == localize("k_nope_ex") then
        for _, v in ipairs(G.jokers.cards) do
            v:calculate_joker({
                wheel_failed = true
            })
        end
    end
end

local copy_card_ref = copy_card
function copy_card(other, new_card, card_scale, playing_card, strip_edition)
    local new = copy_card_ref(other, new_card, card_scale, playing_card, strip_edition)

    if new.ability.bungus_rounds then
        new.ability.bungus_rounds = 0
    end

    return new
end

local add_to_deck_ref = Card.add_to_deck
function Card:add_to_deck(from_debuff)
    add_to_deck_ref(self, from_debuff)

    if self.ability.set == "Joker" and not self.ability.temporary then
        for _, v in ipairs(G.jokers.cards) do
            v:calculate_joker({
                joker_added = true,
                added = self
            })
        end
    end
end

local calculate_joker_ref = Card.calculate_joker
function Card:calculate_joker(context)
    if self.ability.set == "Joker" and context.end_of_round and not context.individual and not context.repetition then
        if self.ability.temporary then
            self.getting_sliced = true

            G.E_MANAGER:add_event(Event({
                func = function()
                    play_sound("tarot1")
                    self.T.r = -0.2
                    self:juice_up(0.3, 0.4)
                    self.states.drag.is = true
                    self.children.center.pinch.x = true

                    G.E_MANAGER:add_event(Event({
                        trigger = "after",
                        delay = 0.3,
                        blockable = false,
                        func = function()
                            G.jokers:remove_card(self)
                            self:remove()
                            self = nil

                            return true
                        end
                    }))

                    return true
                end
            }))

            return {
                message = localize("k_broken_ex")
            }
        elseif G.GAME.blind.name == "The Void" and not G.GAME.blind.disabled then
            self.sell_cost = 0
            G.E_MANAGER:add_event(Event({
                func = function()
                    G.GAME.blind:wiggle()

                    return true
                end
            }))

            return {
                message = localize("k_voided_ex")
            }
        end
    end

    return calculate_joker_ref(self, context)
end

local remove_from_deck_ref = Card.remove_from_deck
function Card:remove_from_deck(from_debuff)
    local flag = (self.added_to_deck and not self.ability.consumable_used and not self.ability.sold) or (G.playing_cards and self.playing_card) and G.jokers

    remove_from_deck_ref(self, from_debuff)

    if flag then
        for _, v in ipairs(G.jokers.cards) do
            if v ~= self then
                v:calculate_joker({
                    any_card_destroyed = true,
                    card = self
                })
            end
        end
    end

end

local use_consumeable_ref = Card.use_consumeable
function Card:use_consumeable(area, copier)
    if not self.debuff then
        self.ability.consumable_used = true
    end

    use_consumeable_ref(self, area, copier)
end

local sell_card_ref = Card.sell_card
function Card:sell_card()
    self.ability.sold = true

    sell_card_ref(self)
end

local set_ability_ref = Card.set_ability
function Card:set_ability(center, initial, delay_sprites)
    set_ability_ref(self, center, initial, delay_sprites)

    if self.ability.name == "Bustling Fungus" then
        self.ability.bungus_rounds = 0
    elseif self.ability.name == "Kjaro's Band" then
        self.ability.enabled = false
    end
end

local set_cost_ref = Card.set_cost
function Card:set_cost()
    set_cost_ref(self)

    if self.ability.temporary then
        self.sell_cost = 0
    elseif self.ability.eulogyed then
        self.cost = math.floor(self.cost * 0.5)
        self.sell_cost = math.max(1, math.floor(self.cost / 2)) + (self.ability.extra_value or 0)
    end

    self.sell_cost_label = self.facing == "back" and "?" or self.sell_cost
end

local create_card_for_shop_ref = create_card_for_shop
function create_card_for_shop(area)
    local card = create_card_for_shop_ref(area)
    local eulogy = find_joker("Eulogy Zero")

    if #eulogy > 0 and pseudorandom("eulogy") < G.GAME.probabilities.normal / eulogy[1].ability.extra then
        card.ability.eulogyed = true
    end

    return card
end

local emplace_ref = CardArea.emplace
function CardArea:emplace(card, location, stay_flipped)
    emplace_ref(self, card, location, stay_flipped)

    if card.ability.eulogyed then
        if self == G.shop_jokers then
            card:flip() -- Unflipping is handled in emplace_ref()
            card:set_cost()
        end
    end
end

function ease_required_chips(mod)
    G.E_MANAGER:add_event(Event({
        trigger = "immediate",
        func = function()
            local chip_UI = G.hand_text_area.blind_chips

            G.E_MANAGER:add_event(Event({
                trigger = "ease",
                blockable = false,
                ref_table = G.GAME.blind,
                ref_value = "chips",
                ease_to = mod or 0,
                delay = 0.3,
                func = function(t)
                    local val = math.floor(t)
                    G.GAME.blind.chip_text = number_format(val)

                    return val
                end
            }))
            G.E_MANAGER:add_event(Event({
                trigger = "after",
                delay = 0.5,
                blockable = false,
                func = function()
                    save_run()

                    return true
                end
            }))

            chip_UI:juice_up()

            return true
        end
      }))
end

local set_blind_ref = Blind.set_blind
function Blind:set_blind(blind, reset, silent)
    if not reset and blind then
        self.children.animatedSprite.atlas = G.ANIMATION_ATLAS[blind.atlas and blind.atlas or "blind_chips"]
    end

    set_blind_ref(self, blind, reset, silent)

    if reset then
        return
    end

    if self.name == "Glaucous Hammer" then
        local cards = {}
        for _, v in ipairs(G.playing_cards) do
            table.insert(cards, v)
        end

        table.sort(cards, function (a, b) return not a.playing_card or not b.playing_card or a.playing_card < b.playing_card end)
        pseudoshuffle(cards, pseudoseed("glaucous"))

        for i = 1, math.floor(#G.playing_cards * 0.5) do
            cards[i].ability.hammered = true
        end

        for _, v in ipairs(G.playing_cards) do
            self:debuff_card(v)
        end
    elseif self.name == "Tyrian Crab" then
        self.prepped = nil
    end
end

local press_play_ref = Blind.press_play
function Blind:press_play()
    if self.disabled then
        return
    end

    if self.name == "Tyrian Crab" then
        self.prepped = true
    end

    return press_play_ref(self)
end

local drawn_to_hand_ref = Blind.drawn_to_hand
function Blind:drawn_to_hand()
    if not self.disabled then
        if self.name == "The Loop" and G.GAME.current_round.hands_played == 2 and G.jokers.cards[1] then
            local jokers = {}
            for _, v in ipairs(G.jokers.cards) do
                table.insert(jokers, v)
                v:set_debuff(false)
            end

            local card = pseudorandom_element(jokers, pseudoseed("the_loop"))
            if card then
                card:set_debuff(true)
                card:juice_up()
                self:wiggle()
            end
        elseif self.name == "Tyrian Crab" and self.prepped then
            ease_required_chips(self.chips * 1.05)
            self:wiggle()
        end
    end

    drawn_to_hand_ref(self)
end

local defeat_ref = Blind.defeat
function Blind:defeat(silent)
    defeat_ref(self, silent)

    -- if self.name == "Tyrian Crab" then
    --     ease_required_chips(get_blind_amount(G.GAME.round_resets.ante) * self.mult * G.GAME.starting_params.ante_scaling)
    -- end
end

local disable_ref = Blind.disable
function Blind:disable()
    disable_ref(self)

    if self.name == "Tyrian Crab" then
        ease_required_chips(get_blind_amount(G.GAME.round_resets.ante) * self.mult * G.GAME.starting_params.ante_scaling)
    end
end

local get_badge_colour_ref = get_badge_colour
function get_badge_colour(key)
    if key == "temporary" then
        return G.C.GREY
    end

    return get_badge_colour_ref(key)
end