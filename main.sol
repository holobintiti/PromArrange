// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// PromArrange — velvet corridor prom ledger (codename: corsage index / gymnasium dusk).
// Remix: compiler 0.8.24, optimizer 200 runs, deploy with zero args.

contract PromArrange {
    // ---- errors ----
    error PA_NotCurator(address caller);
    error PA_NotPendingCurator(address caller);
    error PA_NoPendingCurator();
    error PA_DeskFrozen();
    error PA_Reentrant();
    error PA_ZeroAddress();
    error PA_EventMissing(uint256 eventId);
    error PA_EventSealed(uint256 eventId);
    error PA_EventNotSealed(uint256 eventId);
    error PA_GuestCap(uint256 eventId);
    error PA_TierMissing(uint256 eventId, uint8 tierId);
    error PA_TierSoldOut(uint256 eventId, uint8 tierId);
    error PA_TierInactive(uint256 eventId, uint8 tierId);
    error PA_AlreadyRsvp(uint256 eventId, address guest);
    error PA_NotRsvp(uint256 eventId, address guest);
    error PA_RsvpClosed(uint256 eventId);
    error PA_VenueTaken(uint256 eventId, uint8 slotId);
    error PA_VenueMissing(uint256 eventId, uint8 slotId);
    error PA_ChaperoneFull(uint256 eventId);
    error PA_ChaperoneMissing(uint256 eventId, address chaperone);
    error PA_AlreadyChaperone(uint256 eventId, address chaperone);
    error PA_ThemeCap(uint256 eventId);
    error PA_ThemeMissing(uint256 eventId, uint8 optionId);
    error PA_ThemeClosed(uint256 eventId);
    error PA_PlaylistCap(uint256 eventId);
    error PA_PlaylistMissing(uint256 eventId, uint256 entryId);
    error PA_CourtCap(uint256 eventId);
    error PA_CourtMissing(uint256 eventId, uint256 nomineeId);
    error PA_AlreadyNominated(uint256 eventId, address nominee);
    error PA_SponsorCap(uint256 eventId);
    error PA_PledgeLow();
    error PA_PledgeHigh();
    error PA_BudgetCap(uint256 eventId);
    error PA_BudgetLineMissing(uint256 eventId, uint256 lineId);
    error PA_BudgetOverrun(uint256 eventId, uint256 lineId);
    error PA_TransferFail();
    error PA_BatchTooLarge();
    error PA_ArrayMismatch();
    error PA_NotSeat(address caller, uint8 seatKind);
    error PA_EpochStale(uint256 eventId, uint64 epochId);
    error PA_HypeRange();
    error PA_DigestMismatch(bytes32 supplied, bytes32 computed);

    // ---- events ----
    event Opened(uint256 indexed eventId, address indexed host, bytes32 themeSeed, uint64 opensAt);
    event Sealed(uint256 indexed eventId, address indexed curator, uint64 sealedAt);
    event CuratorQueued(address indexed pending);
    event CuratorAccepted(address indexed curator);
    event DeskFreezeSet(bool frozen, uint64 at);
    event TierSet(uint256 indexed eventId, uint8 indexed tierId, uint256 priceWei, uint16 cap, bool active);
    event Rsvp(uint256 indexed eventId, address indexed guest, uint8 tierId, uint256 paidWei);
    event RsvpCancelled(uint256 indexed eventId, address indexed guest);
    event VenueBooked(uint256 indexed eventId, uint8 indexed slotId, string label, uint256 depositWei);
    event ChaperoneJoined(uint256 indexed eventId, address indexed chaperone);
    event ChaperoneLeft(uint256 indexed eventId, address indexed chaperone);
    event ThemeOption(uint256 indexed eventId, uint8 indexed optionId, string label, uint32 voteWeight);
    event ThemeVoted(uint256 indexed eventId, address indexed voter, uint8 optionId, uint32 weight);
    event PlaylistAdded(uint256 indexed eventId, uint256 indexed entryId, address indexed submitter, bytes32 trackHash);
    event CourtNominated(uint256 indexed eventId, uint256 indexed nomineeId, address indexed nominee, address nominator);
    event CourtVoted(uint256 indexed eventId, uint256 indexed nomineeId, address indexed voter, uint32 votes);
    event SponsorPledged(uint256 indexed eventId, address indexed sponsor, uint256 amountWei, bytes32 memoHash);
    event BudgetLine(uint256 indexed eventId, uint256 indexed lineId, uint8 category, uint256 ceilingWei);
    event BudgetSpent(uint256 indexed eventId, uint256 indexed lineId, uint256 amountWei, address spender);
    event EpochRolled(uint256 indexed eventId, uint64 indexed epochId, uint64 span);
    event HypeSet(uint256 indexed eventId, uint32 hypeScore);

    // ---- anchors (max 3 address constants) ----
    address private constant ADDRESS_A = 0x844Fca2a9bB5CcAD5D0b3980CeC5bFac2aC26bFa;
    address private constant ADDRESS_B = 0x6B2eb8a02aBee8efe30ec373F8e69A2c05EAe84c;
    address private constant ADDRESS_C = 0xFb6E57Fa18A0A028AAeb26be2DA9a6bd3f3a5570;
    bytes32 private constant DOMAIN_SALT = 0xc5A234D49E9ceF2aE9cc2dC02aeFcCC9e3b298FcA513e6CA3306F18D35ddC00C;
    bytes32 private constant THEME_ROOT = 0x107E8A33eF94c4d85a1cA1E85FC7B3b8a0daeF95cb33E88fafCBD2056bd1631F;
    bytes32 private constant VENUE_SEED = 0x7A67d77C570d8df7d2E1d970d37f9063d60d4AE87Bb6ab67D179f5E9CA5c7bAB;
    bytes32 private constant COURT_SALT = 0x7c2fA635B968fFDD9c9F34eCa5Abdb6FE6BAa5da36C7FbC62861A4cd109F04FC;

    // ---- numeric constants ----
    uint256 public constant VERSION = 417;
    uint256 public constant MAX_PROM_EVENTS = 847;
    uint256 public constant MAX_GUESTS_PER_EVENT = 512;
    uint256 public constant MAX_TICKET_TIERS = 9;
    uint256 public constant MAX_VENUE_SLOTS = 64;
    uint256 public constant MAX_CHAPERONE_SLOTS = 24;
    uint256 public constant MAX_THEME_OPTIONS = 16;
    uint256 public constant MAX_PLAYLIST_ENTRIES = 128;
    uint256 public constant MAX_COURT_NOMINEES = 48;
    uint256 public constant MAX_SPONSOR_PLEDGES = 96;
    uint256 public constant MAX_BUDGET_LINES = 72;
    uint64 public constant RSVP_DEADLINE_GRACE = 86400;
    uint64 public constant EARLY_BIRD_WINDOW = 604800;
    uint16 public constant VIP_CAP_DEFAULT = 37;
    uint16 public constant GENERAL_CAP_DEFAULT = 311;
    uint256 public constant MIN_PLEDGE_WEI = 3000000000000000;
    uint256 public constant MAX_PLEDGE_WEI = 18000000000000000000;
    uint256 public constant TICKET_BASE_WEI = 47000000000000000;
    uint256 public constant BUDGET_LINE_CAP = 9999000000000000000;
    uint32 public constant THEME_VOTE_WEIGHT = 3;
    uint16 public constant CHAPERONE_RATIO_BPS = 2150;
    uint16 public constant SPONSOR_FEE_BPS = 275;
    uint256 public constant PLAYLIST_FEE_WEI = 890000000000000;
    uint256 public constant COURT_VOTE_COST = 1200000000000000;
    uint64 public constant EPOCH_SPAN = 302400;
    uint64 public constant DESK_GRACE_BLOCKS = 1440;
    uint256 public constant MAX_BATCH_RSVP = 19;
    uint256 public constant MAX_BATCH_NOMINATE = 11;
    uint32 public constant HYPE_FLOOR = 143;
    uint32 public constant HYPE_CEILING = 8773;
    uint16 public constant DECOR_BUDGET_BPS = 4820;
    uint16 public constant CATERING_BUDGET_BPS = 3910;
    uint16 public constant MUSIC_BUDGET_BPS = 2640;
    uint16 public constant TRANSPORT_BUDGET_BPS = 1180;
    uint16 public constant MISC_BUDGET_BPS = 450;

    // ---- seat kinds ----
    uint8 private constant _SEAT_THEME = 1;
    uint8 private constant _SEAT_VENUE = 2;
    uint8 private constant _SEAT_CHAPERONE = 3;
    uint8 private constant _SEAT_SPONSOR = 4;
    uint8 private constant _SEAT_PLAYLIST = 5;
    uint8 private constant _SEAT_COURT = 6;
    uint8 private constant _SEAT_BUDGET = 7;
    uint8 private constant _SEAT_RSVP = 8;

    // ---- immutables ----
    address public immutable themeOracle;
    address public immutable venueLiaison;
    address public immutable chaperoneSeat;
    address public immutable sponsorDesk;
    address public immutable playlistRelay;
    address public immutable courtScribe;
    address public immutable budgetClerk;
    address public immutable rsvpGate;

    // ---- authority ----
    address public curator;
    address public pendingCurator;
    bool public deskFrozen;
    uint64 public deskFrozenAt;

    // ---- global counters ----
    uint256 public nextEventId;
    uint256 private _gate;

    struct PromEvent {
        address host;
        bytes32 themeSeed;
        uint64 openedAt;
        uint64 rsvpClosesAt;
        uint64 sealedAt;
        bool isSealed;
        uint16 guestCount;
        uint16 chaperoneCount;
        uint16 themeOptionCount;
        uint16 playlistCount;
        uint16 courtNomineeCount;
        uint16 sponsorCount;
        uint16 budgetLineCount;
        uint32 hypeScore;
        uint64 currentEpoch;
        uint64 epochEndsAt;
        uint256 totalPledgedWei;
        uint256 totalSpentWei;
    }

    struct TicketTier {
        uint256 priceWei;
        uint16 cap;
        uint16 sold;
        bool active;
        bytes32 tierTag;
    }

    struct RsvpRecord {
        uint8 tierId;
        uint256 paidWei;
        uint64 rsvpedAt;
        bool cancelled;
    }

    struct VenueSlot {
        string label;
        uint256 depositWei;
        address bookedBy;
        bool taken;
    }

    struct ThemeOptionEntry {
        string label;
        uint32 voteWeight;
        uint32 totalVotes;
        bool active;
    }

    struct PlaylistEntry {
        address submitter;
        bytes32 trackHash;
        uint64 addedAt;
        bool removed;
    }

    struct CourtNominee {
        address nominee;
        address nominator;
        uint32 voteTotal;
        bool withdrawn;
    }

    struct SponsorPledge {
        address sponsor;
        uint256 amountWei;
        bytes32 memoHash;
        uint64 pledgedAt;
    }

    struct BudgetLineEntry {
        uint8 category;
        uint256 ceilingWei;
        uint256 spentWei;
        bool closed;
    }

    mapping(uint256 => PromEvent) public events;
    mapping(uint256 => mapping(uint8 => TicketTier)) public tiers;
    mapping(uint256 => mapping(address => RsvpRecord)) public rsvps;
    mapping(uint256 => address[]) public guestList;
    mapping(uint256 => mapping(uint8 => VenueSlot)) public venueSlots;
    mapping(uint256 => address[]) public chaperones;
    mapping(uint256 => mapping(address => bool)) public isChaperone;
    mapping(uint256 => mapping(uint8 => ThemeOptionEntry)) public themeOptions;
    mapping(uint256 => mapping(uint256 => PlaylistEntry)) public playlist;
    mapping(uint256 => mapping(uint256 => CourtNominee)) public courtNominees;
    mapping(uint256 => mapping(address => uint256)) public nomineeIdByAddress;
    mapping(uint256 => mapping(uint256 => SponsorPledge)) public sponsorPledges;
    mapping(uint256 => mapping(uint256 => BudgetLineEntry)) public budgetLines;
    mapping(uint256 => mapping(address => mapping(uint8 => bool))) public themeVotes;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public courtVotes;

    modifier nonReentrant() {
        if (_gate == 2) revert PA_Reentrant();
        _gate = 2;
        _;
        _gate = 1;
    }

    modifier onlyCurator() {
        if (msg.sender != curator) revert PA_NotCurator(msg.sender);
        _;
    }

    modifier notFrozen() {
        if (deskFrozen) revert PA_DeskFrozen();
        _;
    }

    modifier eventExists(uint256 eventId) {
        if (events[eventId].host == address(0)) revert PA_EventMissing(eventId);
        _;
    }

    modifier eventOpen(uint256 eventId) {
        if (events[eventId].isSealed) revert PA_EventSealed(eventId);
        _;
    }

    constructor() {
        themeOracle = 0xCfa7C1ffEBF123eeaD2Bfef1ea591A3Bab8B2d1d;
        venueLiaison = 0x25abFBbd1d08Aab70dFa1488d1eB8ED476E2CFea;
        chaperoneSeat = 0xC93Be8eFDC31dB0aFb74eE8Df2EDE66f60fFfd2A;
        sponsorDesk = 0xAA4Ebe0beDdC176d8Cb4c12Da3fC517BCB9Ce68B;
        playlistRelay = 0x7FE4AAE7aEe2D2aaCCc11e503d5f89f0ea72C7Ff;
        courtScribe = 0xAaAAaA2fBeD6C2Af71D86Dfd09dBEA14CC50Dbc0;
        budgetClerk = 0xf05e9e5a9e5ceb91Cace26aCB3e3fcED69A3a521;
        rsvpGate = 0xD1bF5995AfE5becdBBccC506bBBFCacB4aDC13ce;
        curator = msg.sender;
        pendingCurator = address(0);
        deskFrozen = false;
        deskFrozenAt = 0;
        nextEventId = 1;
        _gate = 1;
    }

    // ---- curator handoff (2-step) ----
    function queueCurator(address next) external onlyCurator {
        if (next == address(0)) revert PA_ZeroAddress();
        pendingCurator = next;
        emit CuratorQueued(next);
    }

    function acceptCurator() external {
        if (msg.sender != pendingCurator) revert PA_NotPendingCurator(msg.sender);
        if (pendingCurator == address(0)) revert PA_NoPendingCurator();
        curator = pendingCurator;
        pendingCurator = address(0);
        emit CuratorAccepted(curator);
    }

    function setDeskFrozen(bool frozen) external onlyCurator {
        deskFrozen = frozen;
        deskFrozenAt = uint64(block.timestamp);
        emit DeskFreezeSet(frozen, deskFrozenAt);
    }

    // ---- event lifecycle ----
    function openEvent(bytes32 themeSeed, uint64 rsvpWindow) external notFrozen returns (uint256 eventId) {
        if (rsvpWindow < RSVP_DEADLINE_GRACE) revert PA_RsvpClosed(0);
        eventId = nextEventId++;
        uint64 nowTs = uint64(block.timestamp);
        PromEvent storage ev = events[eventId];
        ev.host = msg.sender;
        ev.themeSeed = themeSeed;
        ev.openedAt = nowTs;
        ev.rsvpClosesAt = nowTs + rsvpWindow;
        ev.currentEpoch = 1;
        ev.epochEndsAt = nowTs + EPOCH_SPAN;
        ev.hypeScore = HYPE_FLOOR;
        _seedDefaultTiers(eventId);
        emit Opened(eventId, msg.sender, themeSeed, nowTs);
    }

    function sealEvent(uint256 eventId) external eventExists(eventId) {
        PromEvent storage ev = events[eventId];
        if (ev.isSealed) revert PA_EventSealed(eventId);
        if (msg.sender != ev.host && msg.sender != curator) revert PA_NotCurator(msg.sender);
        ev.isSealed = true;
        ev.sealedAt = uint64(block.timestamp);
        emit Sealed(eventId, msg.sender, ev.sealedAt);
    }

    function _seedDefaultTiers(uint256 eventId) private {
        tiers[eventId][0] = TicketTier({
            priceWei: TICKET_BASE_WEI,
            cap: GENERAL_CAP_DEFAULT,
            sold: 0,
            active: true,
            tierTag: keccak256(abi.encode(DOMAIN_SALT, eventId, uint8(0)))
        });
        tiers[eventId][1] = TicketTier({
            priceWei: TICKET_BASE_WEI * 2,
            cap: VIP_CAP_DEFAULT,
            sold: 0,
            active: true,
            tierTag: keccak256(abi.encode(DOMAIN_SALT, eventId, uint8(1)))
        });
        emit TierSet(eventId, 0, TICKET_BASE_WEI, GENERAL_CAP_DEFAULT, true);
        emit TierSet(eventId, 1, TICKET_BASE_WEI * 2, VIP_CAP_DEFAULT, true);
    }

    function configureTier(
        uint256 eventId,
        uint8 tierId,
        uint256 priceWei,
        uint16 cap,
        bool active
    ) external eventExists(eventId) eventOpen(eventId) {
        PromEvent storage ev = events[eventId];
        if (msg.sender != ev.host && msg.sender != curator) revert PA_NotCurator(msg.sender);
        if (tierId >= MAX_TICKET_TIERS) revert PA_TierMissing(eventId, tierId);
        tiers[eventId][tierId] = TicketTier({
            priceWei: priceWei,
            cap: cap,
            sold: tiers[eventId][tierId].sold,
            active: active,
            tierTag: keccak256(abi.encode(DOMAIN_SALT, eventId, tierId))
        });
        emit TierSet(eventId, tierId, priceWei, cap, active);
    }

    function rsvp(uint256 eventId, uint8 tierId) external payable nonReentrant eventExists(eventId) eventOpen(eventId) notFrozen {
        PromEvent storage ev = events[eventId];
        if (block.timestamp > ev.rsvpClosesAt) revert PA_RsvpClosed(eventId);
        if (ev.guestCount >= MAX_GUESTS_PER_EVENT) revert PA_GuestCap(eventId);
        if (rsvps[eventId][msg.sender].rsvpedAt != 0 && !rsvps[eventId][msg.sender].cancelled) {
            revert PA_AlreadyRsvp(eventId, msg.sender);
        }
        TicketTier storage tier = tiers[eventId][tierId];
        if (!tier.active) revert PA_TierInactive(eventId, tierId);
        if (tier.sold >= tier.cap) revert PA_TierSoldOut(eventId, tierId);
        if (msg.value < tier.priceWei) revert PA_PledgeLow();
        tier.sold += 1;
        ev.guestCount += 1;
        rsvps[eventId][msg.sender] = RsvpRecord({
            tierId: tierId,
            paidWei: msg.value,
            rsvpedAt: uint64(block.timestamp),
            cancelled: false
        });
        guestList[eventId].push(msg.sender);
        emit Rsvp(eventId, msg.sender, tierId, msg.value);
    }

    function cancelRsvp(uint256 eventId) external nonReentrant eventExists(eventId) eventOpen(eventId) {
        RsvpRecord storage rec = rsvps[eventId][msg.sender];
        if (rec.rsvpedAt == 0 || rec.cancelled) revert PA_NotRsvp(eventId, msg.sender);
        rec.cancelled = true;
        PromEvent storage ev = events[eventId];
        ev.guestCount -= 1;
        TicketTier storage tier = tiers[eventId][rec.tierId];
        if (tier.sold > 0) tier.sold -= 1;
        uint256 refund = rec.paidWei;
        rec.paidWei = 0;
        (bool ok, ) = msg.sender.call{value: refund}("");
        if (!ok) revert PA_TransferFail();
        emit RsvpCancelled(eventId, msg.sender);
    }

    function batchRsvp(
        uint256 eventId,
        address[] calldata guests,
        uint8[] calldata tierIds
    ) external payable nonReentrant eventExists(eventId) eventOpen(eventId) notFrozen {
        if (msg.sender != rsvpGate && msg.sender != curator) revert PA_NotSeat(msg.sender, _SEAT_RSVP);
        uint256 len = guests.length;
        if (len == 0 || len > MAX_BATCH_RSVP) revert PA_BatchTooLarge();
        if (tierIds.length != len) revert PA_ArrayMismatch();
        uint256 totalDue;
        for (uint256 i; i < len; ) {
            TicketTier storage tier = tiers[eventId][tierIds[i]];
            if (!tier.active || tier.sold >= tier.cap) revert PA_TierSoldOut(eventId, tierIds[i]);
            totalDue += tier.priceWei;
            unchecked { ++i; }
        }
        if (msg.value < totalDue) revert PA_PledgeLow();
        for (uint256 i; i < len; ) {
            address guest = guests[i];
            uint8 tierId = tierIds[i];
            TicketTier storage tier = tiers[eventId][tierId];
            tier.sold += 1;
            events[eventId].guestCount += 1;
            rsvps[eventId][guest] = RsvpRecord({
                tierId: tierId,
                paidWei: tier.priceWei,
                rsvpedAt: uint64(block.timestamp),
                cancelled: false
            });
            guestList[eventId].push(guest);
            emit Rsvp(eventId, guest, tierId, tier.priceWei);
            unchecked { ++i; }
        }
    }


    // ---- venue booking ----
    function bookVenueSlot(
        uint256 eventId,
        uint8 slotId,
        string calldata label
    ) external payable nonReentrant eventExists(eventId) eventOpen(eventId) notFrozen {
        if (msg.sender != venueLiaison && msg.sender != events[eventId].host) {
            revert PA_NotSeat(msg.sender, _SEAT_VENUE);
        }
        if (slotId >= MAX_VENUE_SLOTS) revert PA_VenueMissing(eventId, slotId);
        VenueSlot storage slot = venueSlots[eventId][slotId];
        if (slot.taken) revert PA_VenueTaken(eventId, slotId);
        slot.label = label;
        slot.depositWei = msg.value;
        slot.bookedBy = msg.sender;
        slot.taken = true;
        emit VenueBooked(eventId, slotId, label, msg.value);
    }

    function venueDigestPart0(uint256 eventId, uint8 slotId) external view returns (bytes32) {
        VenueSlot storage slot = venueSlots[eventId][slotId];
        return keccak256(abi.encode(VENUE_SEED, eventId, slotId, slot.label, slot.depositWei, uint8(0)));
    }

    function venueDigestPart1(uint256 eventId, uint8 slotId) external view returns (bytes32) {
        VenueSlot storage slot = venueSlots[eventId][slotId];
        return keccak256(abi.encode(VENUE_SEED, eventId, slotId, slot.label, slot.depositWei, uint8(1)));
    }

    function venueDigestPart2(uint256 eventId, uint8 slotId) external view returns (bytes32) {
        VenueSlot storage slot = venueSlots[eventId][slotId];
        return keccak256(abi.encode(VENUE_SEED, eventId, slotId, slot.label, slot.depositWei, uint8(2)));
    }

    function venueDigestPart3(uint256 eventId, uint8 slotId) external view returns (bytes32) {
        VenueSlot storage slot = venueSlots[eventId][slotId];
        return keccak256(abi.encode(VENUE_SEED, eventId, slotId, slot.label, slot.depositWei, uint8(3)));
    }

    function venueDigestPart4(uint256 eventId, uint8 slotId) external view returns (bytes32) {
        VenueSlot storage slot = venueSlots[eventId][slotId];
        return keccak256(abi.encode(VENUE_SEED, eventId, slotId, slot.label, slot.depositWei, uint8(4)));
    }

    function venueDigestPart5(uint256 eventId, uint8 slotId) external view returns (bytes32) {
        VenueSlot storage slot = venueSlots[eventId][slotId];
        return keccak256(abi.encode(VENUE_SEED, eventId, slotId, slot.label, slot.depositWei, uint8(5)));
    }

    function venueDigestPart6(uint256 eventId, uint8 slotId) external view returns (bytes32) {
        VenueSlot storage slot = venueSlots[eventId][slotId];
        return keccak256(abi.encode(VENUE_SEED, eventId, slotId, slot.label, slot.depositWei, uint8(6)));
    }

    function venueDigestPart7(uint256 eventId, uint8 slotId) external view returns (bytes32) {
        VenueSlot storage slot = venueSlots[eventId][slotId];
        return keccak256(abi.encode(VENUE_SEED, eventId, slotId, slot.label, slot.depositWei, uint8(7)));
    }

    function venueDigestPart8(uint256 eventId, uint8 slotId) external view returns (bytes32) {
        VenueSlot storage slot = venueSlots[eventId][slotId];
        return keccak256(abi.encode(VENUE_SEED, eventId, slotId, slot.label, slot.depositWei, uint8(8)));
    }

    function venueDigestPart9(uint256 eventId, uint8 slotId) external view returns (bytes32) {
        VenueSlot storage slot = venueSlots[eventId][slotId];
        return keccak256(abi.encode(VENUE_SEED, eventId, slotId, slot.label, slot.depositWei, uint8(9)));
    }

    function venueDigestPart10(uint256 eventId, uint8 slotId) external view returns (bytes32) {
        VenueSlot storage slot = venueSlots[eventId][slotId];
        return keccak256(abi.encode(VENUE_SEED, eventId, slotId, slot.label, slot.depositWei, uint8(10)));
    }

    function venueDigestPart11(uint256 eventId, uint8 slotId) external view returns (bytes32) {
        VenueSlot storage slot = venueSlots[eventId][slotId];
        return keccak256(abi.encode(VENUE_SEED, eventId, slotId, slot.label, slot.depositWei, uint8(11)));
    }

    // ---- chaperone roster ----
    function joinChaperone(uint256 eventId) external eventExists(eventId) eventOpen(eventId) notFrozen {
        if (msg.sender != chaperoneSeat && msg.sender != curator) revert PA_NotSeat(msg.sender, _SEAT_CHAPERONE);
        PromEvent storage ev = events[eventId];
        if (ev.chaperoneCount >= MAX_CHAPERONE_SLOTS) revert PA_ChaperoneFull(eventId);
        if (isChaperone[eventId][msg.sender]) revert PA_AlreadyChaperone(eventId, msg.sender);
        isChaperone[eventId][msg.sender] = true;
        chaperones[eventId].push(msg.sender);
        ev.chaperoneCount += 1;
        emit ChaperoneJoined(eventId, msg.sender);
    }

    function leaveChaperone(uint256 eventId) external eventExists(eventId) {
        if (!isChaperone[eventId][msg.sender]) revert PA_ChaperoneMissing(eventId, msg.sender);
        isChaperone[eventId][msg.sender] = false;
        events[eventId].chaperoneCount -= 1;
        emit ChaperoneLeft(eventId, msg.sender);
    }

    function chaperoneRatioCheck0(uint256 eventId) external view returns (bool ok, uint256 ratioBps) {
        PromEvent storage ev = events[eventId];
        if (ev.guestCount == 0) return (true, 0);
        ratioBps = (uint256(ev.chaperoneCount) * 10000) / uint256(ev.guestCount);
        ok = ratioBps >= CHAPERONE_RATIO_BPS - uint256(0);
    }

    function chaperoneRatioCheck1(uint256 eventId) external view returns (bool ok, uint256 ratioBps) {
        PromEvent storage ev = events[eventId];
        if (ev.guestCount == 0) return (true, 0);
        ratioBps = (uint256(ev.chaperoneCount) * 10000) / uint256(ev.guestCount);
        ok = ratioBps >= CHAPERONE_RATIO_BPS - uint256(1);
    }

    function chaperoneRatioCheck2(uint256 eventId) external view returns (bool ok, uint256 ratioBps) {
        PromEvent storage ev = events[eventId];
        if (ev.guestCount == 0) return (true, 0);
        ratioBps = (uint256(ev.chaperoneCount) * 10000) / uint256(ev.guestCount);
        ok = ratioBps >= CHAPERONE_RATIO_BPS - uint256(2);
    }

    function chaperoneRatioCheck3(uint256 eventId) external view returns (bool ok, uint256 ratioBps) {
        PromEvent storage ev = events[eventId];
        if (ev.guestCount == 0) return (true, 0);
        ratioBps = (uint256(ev.chaperoneCount) * 10000) / uint256(ev.guestCount);
        ok = ratioBps >= CHAPERONE_RATIO_BPS - uint256(3);
    }

    function chaperoneRatioCheck4(uint256 eventId) external view returns (bool ok, uint256 ratioBps) {
        PromEvent storage ev = events[eventId];
        if (ev.guestCount == 0) return (true, 0);
        ratioBps = (uint256(ev.chaperoneCount) * 10000) / uint256(ev.guestCount);
        ok = ratioBps >= CHAPERONE_RATIO_BPS - uint256(4);
    }

    function chaperoneRatioCheck5(uint256 eventId) external view returns (bool ok, uint256 ratioBps) {
        PromEvent storage ev = events[eventId];
        if (ev.guestCount == 0) return (true, 0);
        ratioBps = (uint256(ev.chaperoneCount) * 10000) / uint256(ev.guestCount);
        ok = ratioBps >= CHAPERONE_RATIO_BPS - uint256(5);
    }

    function chaperoneRatioCheck6(uint256 eventId) external view returns (bool ok, uint256 ratioBps) {
        PromEvent storage ev = events[eventId];
        if (ev.guestCount == 0) return (true, 0);
        ratioBps = (uint256(ev.chaperoneCount) * 10000) / uint256(ev.guestCount);
        ok = ratioBps >= CHAPERONE_RATIO_BPS - uint256(6);
    }

    function chaperoneRatioCheck7(uint256 eventId) external view returns (bool ok, uint256 ratioBps) {
        PromEvent storage ev = events[eventId];
        if (ev.guestCount == 0) return (true, 0);
        ratioBps = (uint256(ev.chaperoneCount) * 10000) / uint256(ev.guestCount);
        ok = ratioBps >= CHAPERONE_RATIO_BPS - uint256(7);
    }

    // ---- theme voting ----
    function addThemeOption(uint256 eventId, uint8 optionId, string calldata label) external eventExists(eventId) eventOpen(eventId) notFrozen {
        if (msg.sender != themeOracle && msg.sender != events[eventId].host) revert PA_NotSeat(msg.sender, _SEAT_THEME);
        if (optionId >= MAX_THEME_OPTIONS) revert PA_ThemeCap(eventId);
        ThemeOptionEntry storage opt = themeOptions[eventId][optionId];
        if (bytes(opt.label).length != 0) revert PA_ThemeCap(eventId);
        opt.label = label;
        opt.voteWeight = THEME_VOTE_WEIGHT;
        opt.active = true;
        events[eventId].themeOptionCount += 1;
        emit ThemeOption(eventId, optionId, label, THEME_VOTE_WEIGHT);
    }

    function voteTheme(uint256 eventId, uint8 optionId) external eventExists(eventId) eventOpen(eventId) notFrozen {
        ThemeOptionEntry storage opt = themeOptions[eventId][optionId];
        if (!opt.active || bytes(opt.label).length == 0) revert PA_ThemeMissing(eventId, optionId);
        if (themeVotes[eventId][msg.sender][optionId]) revert PA_AlreadyRsvp(eventId, msg.sender);
        themeVotes[eventId][msg.sender][optionId] = true;
        opt.totalVotes += opt.voteWeight;
        emit ThemeVoted(eventId, msg.sender, optionId, opt.voteWeight);
    }

    function themeLeaderboard0(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(0)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard1(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(1)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard2(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(2)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard3(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(3)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard4(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(4)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard5(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(5)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard6(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(6)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard7(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(7)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard8(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(8)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard9(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(9)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard10(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(10)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard11(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(11)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard12(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(12)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard13(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(13)) break;
            unchecked { ++i; }
        }
    }

    function themeLeaderboard14(uint256 eventId) external view returns (uint8 leaderId, uint32 votes) {
        uint16 count = events[eventId].themeOptionCount;
        for (uint8 i; i < count; ) {
            ThemeOptionEntry storage opt = themeOptions[eventId][i];
            if (opt.totalVotes > votes) {
                votes = opt.totalVotes;
                leaderId = i;
            }
            if (i == uint8(14)) break;
            unchecked { ++i; }
        }
    }

    // ---- playlist lane ----
    function submitPlaylistTrack(uint256 eventId, bytes32 trackHash) external payable nonReentrant eventExists(eventId) eventOpen(eventId) notFrozen {
        if (msg.sender != playlistRelay && msg.sender != events[eventId].host) revert PA_NotSeat(msg.sender, _SEAT_PLAYLIST);
        if (msg.value < PLAYLIST_FEE_WEI) revert PA_PledgeLow();
        PromEvent storage ev = events[eventId];
        if (ev.playlistCount >= MAX_PLAYLIST_ENTRIES) revert PA_PlaylistCap(eventId);
        uint256 entryId = ev.playlistCount;
        ev.playlistCount += 1;
        playlist[eventId][entryId] = PlaylistEntry({
            submitter: msg.sender,
            trackHash: trackHash,
            addedAt: uint64(block.timestamp),
            removed: false
        });
        emit PlaylistAdded(eventId, entryId, msg.sender, trackHash);
    }

    function playlistEntryView0(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    function playlistEntryView1(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    function playlistEntryView2(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    function playlistEntryView3(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    function playlistEntryView4(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    function playlistEntryView5(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    function playlistEntryView6(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    function playlistEntryView7(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    function playlistEntryView8(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    function playlistEntryView9(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    function playlistEntryView10(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    function playlistEntryView11(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    function playlistEntryView12(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    function playlistEntryView13(uint256 eventId, uint256 entryId) external view returns (address submitter, bytes32 trackHash, bool removed) {
        PlaylistEntry storage ent = playlist[eventId][entryId];
        if (ent.addedAt == 0) revert PA_PlaylistMissing(eventId, entryId);
        return (ent.submitter, ent.trackHash, ent.removed);
    }

    // ---- prom court ----
    function nominateCourt(uint256 eventId, address nominee) external eventExists(eventId) eventOpen(eventId) notFrozen {
        if (msg.sender != courtScribe && msg.sender != events[eventId].host) revert PA_NotSeat(msg.sender, _SEAT_COURT);
        if (nominee == address(0)) revert PA_ZeroAddress();
        if (nomineeIdByAddress[eventId][nominee] != 0) revert PA_AlreadyNominated(eventId, nominee);
        PromEvent storage ev = events[eventId];
        if (ev.courtNomineeCount >= MAX_COURT_NOMINEES) revert PA_CourtCap(eventId);
        uint256 nomineeId = ev.courtNomineeCount + 1;
        ev.courtNomineeCount += 1;
        courtNominees[eventId][nomineeId] = CourtNominee({
            nominee: nominee,
            nominator: msg.sender,
            voteTotal: 0,
            withdrawn: false
        });
        nomineeIdByAddress[eventId][nominee] = nomineeId;
        emit CourtNominated(eventId, nomineeId, nominee, msg.sender);
    }

    function voteCourt(uint256 eventId, uint256 nomineeId) external payable nonReentrant eventExists(eventId) eventOpen(eventId) notFrozen {
        CourtNominee storage nom = courtNominees[eventId][nomineeId];
        if (nom.nominee == address(0) || nom.withdrawn) revert PA_CourtMissing(eventId, nomineeId);
        if (courtVotes[eventId][nomineeId][msg.sender]) revert PA_AlreadyRsvp(eventId, msg.sender);
        if (msg.value < COURT_VOTE_COST) revert PA_PledgeLow();
        courtVotes[eventId][nomineeId][msg.sender] = true;
        uint32 weight = uint32(1 + (msg.value / COURT_VOTE_COST));
        nom.voteTotal += weight;
        emit CourtVoted(eventId, nomineeId, msg.sender, weight);
    }

    function batchNominateCourt(uint256 eventId, address[] calldata nominees) external eventExists(eventId) eventOpen(eventId) notFrozen {
        if (msg.sender != courtScribe) revert PA_NotSeat(msg.sender, _SEAT_COURT);
        uint256 len = nominees.length;
        if (len == 0 || len > MAX_BATCH_NOMINATE) revert PA_BatchTooLarge();
        for (uint256 i; i < len; ) {
            address nominee = nominees[i];
            if (nominee == address(0)) revert PA_ZeroAddress();
            if (nomineeIdByAddress[eventId][nominee] != 0) revert PA_AlreadyNominated(eventId, nominee);
            PromEvent storage ev = events[eventId];
            if (ev.courtNomineeCount >= MAX_COURT_NOMINEES) revert PA_CourtCap(eventId);
            uint256 nomineeId = ev.courtNomineeCount + 1;
            ev.courtNomineeCount += 1;
            courtNominees[eventId][nomineeId] = CourtNominee({
                nominee: nominee,
                nominator: msg.sender,
                voteTotal: 0,
                withdrawn: false
            });
            nomineeIdByAddress[eventId][nominee] = nomineeId;
            emit CourtNominated(eventId, nomineeId, nominee, msg.sender);
            unchecked { ++i; }
        }
    }

    function courtStanding0(uint256 eventId, uint256 nomineeId) external view returns (address nominee, uint32 votes, bool withdrawn) {
        CourtNominee storage nom = courtNominees[eventId][nomineeId];
        if (nom.nominee == address(0)) revert PA_CourtMissing(eventId, nomineeId);
        return (nom.nominee, nom.voteTotal, nom.withdrawn);
    }

    function courtStanding1(uint256 eventId, uint256 nomineeId) external view returns (address nominee, uint32 votes, bool withdrawn) {
        CourtNominee storage nom = courtNominees[eventId][nomineeId];
        if (nom.nominee == address(0)) revert PA_CourtMissing(eventId, nomineeId);
        return (nom.nominee, nom.voteTotal, nom.withdrawn);
    }

    function courtStanding2(uint256 eventId, uint256 nomineeId) external view returns (address nominee, uint32 votes, bool withdrawn) {
        CourtNominee storage nom = courtNominees[eventId][nomineeId];
        if (nom.nominee == address(0)) revert PA_CourtMissing(eventId, nomineeId);
        return (nom.nominee, nom.voteTotal, nom.withdrawn);
    }

    function courtStanding3(uint256 eventId, uint256 nomineeId) external view returns (address nominee, uint32 votes, bool withdrawn) {
        CourtNominee storage nom = courtNominees[eventId][nomineeId];
        if (nom.nominee == address(0)) revert PA_CourtMissing(eventId, nomineeId);
        return (nom.nominee, nom.voteTotal, nom.withdrawn);
    }

    function courtStanding4(uint256 eventId, uint256 nomineeId) external view returns (address nominee, uint32 votes, bool withdrawn) {
        CourtNominee storage nom = courtNominees[eventId][nomineeId];
        if (nom.nominee == address(0)) revert PA_CourtMissing(eventId, nomineeId);
        return (nom.nominee, nom.voteTotal, nom.withdrawn);
    }

    function courtStanding5(uint256 eventId, uint256 nomineeId) external view returns (address nominee, uint32 votes, bool withdrawn) {
        CourtNominee storage nom = courtNominees[eventId][nomineeId];
        if (nom.nominee == address(0)) revert PA_CourtMissing(eventId, nomineeId);
        return (nom.nominee, nom.voteTotal, nom.withdrawn);
    }

    function courtStanding6(uint256 eventId, uint256 nomineeId) external view returns (address nominee, uint32 votes, bool withdrawn) {
        CourtNominee storage nom = courtNominees[eventId][nomineeId];
        if (nom.nominee == address(0)) revert PA_CourtMissing(eventId, nomineeId);
        return (nom.nominee, nom.voteTotal, nom.withdrawn);
    }

    function courtStanding7(uint256 eventId, uint256 nomineeId) external view returns (address nominee, uint32 votes, bool withdrawn) {
        CourtNominee storage nom = courtNominees[eventId][nomineeId];
        if (nom.nominee == address(0)) revert PA_CourtMissing(eventId, nomineeId);
        return (nom.nominee, nom.voteTotal, nom.withdrawn);
    }

    function courtStanding8(uint256 eventId, uint256 nomineeId) external view returns (address nominee, uint32 votes, bool withdrawn) {
        CourtNominee storage nom = courtNominees[eventId][nomineeId];
        if (nom.nominee == address(0)) revert PA_CourtMissing(eventId, nomineeId);
        return (nom.nominee, nom.voteTotal, nom.withdrawn);
    }

    function courtStanding9(uint256 eventId, uint256 nomineeId) external view returns (address nominee, uint32 votes, bool withdrawn) {
        CourtNominee storage nom = courtNominees[eventId][nomineeId];
        if (nom.nominee == address(0)) revert PA_CourtMissing(eventId, nomineeId);
        return (nom.nominee, nom.voteTotal, nom.withdrawn);
    }

    function courtStanding10(uint256 eventId, uint256 nomineeId) external view returns (address nominee, uint32 votes, bool withdrawn) {
        CourtNominee storage nom = courtNominees[eventId][nomineeId];
        if (nom.nominee == address(0)) revert PA_CourtMissing(eventId, nomineeId);
        return (nom.nominee, nom.voteTotal, nom.withdrawn);
    }

    function courtStanding11(uint256 eventId, uint256 nomineeId) external view returns (address nominee, uint32 votes, bool withdrawn) {
        CourtNominee storage nom = courtNominees[eventId][nomineeId];
        if (nom.nominee == address(0)) revert PA_CourtMissing(eventId, nomineeId);
        return (nom.nominee, nom.voteTotal, nom.withdrawn);
    }

    // ---- sponsors & budget ----
    function pledgeSponsor(uint256 eventId, bytes32 memoHash) external payable nonReentrant eventExists(eventId) eventOpen(eventId) notFrozen {
        if (msg.sender != sponsorDesk && msg.sender != events[eventId].host) revert PA_NotSeat(msg.sender, _SEAT_SPONSOR);
        if (msg.value < MIN_PLEDGE_WEI) revert PA_PledgeLow();
        if (msg.value > MAX_PLEDGE_WEI) revert PA_PledgeHigh();
        PromEvent storage ev = events[eventId];
        if (ev.sponsorCount >= MAX_SPONSOR_PLEDGES) revert PA_SponsorCap(eventId);
        uint256 pledgeId = ev.sponsorCount;
        ev.sponsorCount += 1;
        ev.totalPledgedWei += msg.value;
        sponsorPledges[eventId][pledgeId] = SponsorPledge({
            sponsor: msg.sender,
            amountWei: msg.value,
            memoHash: memoHash,
            pledgedAt: uint64(block.timestamp)
        });
        emit SponsorPledged(eventId, msg.sender, msg.value, memoHash);
    }

    function addBudgetLine(uint256 eventId, uint256 lineId, uint8 category, uint256 ceilingWei) external eventExists(eventId) eventOpen(eventId) notFrozen {
        if (msg.sender != budgetClerk && msg.sender != events[eventId].host) revert PA_NotSeat(msg.sender, _SEAT_BUDGET);
        if (ceilingWei > BUDGET_LINE_CAP) revert PA_BudgetOverrun(eventId, lineId);
        PromEvent storage ev = events[eventId];
        if (ev.budgetLineCount >= MAX_BUDGET_LINES) revert PA_BudgetCap(eventId);
        BudgetLineEntry storage line = budgetLines[eventId][lineId];
        if (line.ceilingWei != 0) revert PA_BudgetCap(eventId);
        ev.budgetLineCount += 1;
        line.category = category;
        line.ceilingWei = ceilingWei;
        line.spentWei = 0;
        line.closed = false;
        emit BudgetLine(eventId, lineId, category, ceilingWei);
    }

    function spendBudgetLine(uint256 eventId, uint256 lineId, uint256 amountWei, address spender) external nonReentrant eventExists(eventId) notFrozen {
        if (msg.sender != budgetClerk && msg.sender != curator) revert PA_NotSeat(msg.sender, _SEAT_BUDGET);
        BudgetLineEntry storage line = budgetLines[eventId][lineId];
        if (line.ceilingWei == 0) revert PA_BudgetLineMissing(eventId, lineId);
        if (line.closed) revert PA_BudgetOverrun(eventId, lineId);
        if (line.spentWei + amountWei > line.ceilingWei) revert PA_BudgetOverrun(eventId, lineId);
        line.spentWei += amountWei;
        events[eventId].totalSpentWei += amountWei;
        (bool ok, ) = spender.call{value: amountWei}("");
        if (!ok) revert PA_TransferFail();
        emit BudgetSpent(eventId, lineId, amountWei, spender);
    }

    function budgetSlice0(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * DECOR_BUDGET_BPS) / 10000;
    }

    function budgetSlice1(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * CATERING_BUDGET_BPS) / 10000;
    }

    function budgetSlice2(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * MUSIC_BUDGET_BPS) / 10000;
    }

    function budgetSlice3(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * TRANSPORT_BUDGET_BPS) / 10000;
    }

    function budgetSlice4(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * MISC_BUDGET_BPS) / 10000;
    }

    function budgetSlice5(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * DECOR_BUDGET_BPS) / 10000;
    }

    function budgetSlice6(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * CATERING_BUDGET_BPS) / 10000;
    }

    function budgetSlice7(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * MUSIC_BUDGET_BPS) / 10000;
    }

    function budgetSlice8(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * TRANSPORT_BUDGET_BPS) / 10000;
    }

    function budgetSlice9(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * MISC_BUDGET_BPS) / 10000;
    }

    function budgetSlice10(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * DECOR_BUDGET_BPS) / 10000;
    }

    function budgetSlice11(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * CATERING_BUDGET_BPS) / 10000;
    }

    function budgetSlice12(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * MUSIC_BUDGET_BPS) / 10000;
    }

    function budgetSlice13(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * TRANSPORT_BUDGET_BPS) / 10000;
    }

    function budgetSlice14(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * MISC_BUDGET_BPS) / 10000;
    }

    function budgetSlice15(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * DECOR_BUDGET_BPS) / 10000;
    }

    function budgetSlice16(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * CATERING_BUDGET_BPS) / 10000;
    }

    function budgetSlice17(uint256 eventId) external view returns (uint256 sliceWei) {
        PromEvent storage ev = events[eventId];
        sliceWei = (ev.totalPledgedWei * MUSIC_BUDGET_BPS) / 10000;
    }

    // ---- epoch & hype ----
    function rollEpoch(uint256 eventId) external eventExists(eventId) eventOpen(eventId) {
        PromEvent storage ev = events[eventId];
        if (block.timestamp < ev.epochEndsAt) revert PA_EpochStale(eventId, ev.currentEpoch);
        ev.currentEpoch += 1;
        ev.epochEndsAt = uint64(block.timestamp) + EPOCH_SPAN;
        emit EpochRolled(eventId, ev.currentEpoch, EPOCH_SPAN);
    }

    function setHypeScore(uint256 eventId, uint32 hypeScore) external eventExists(eventId) {
        if (msg.sender != curator && msg.sender != events[eventId].host) revert PA_NotCurator(msg.sender);
        if (hypeScore < HYPE_FLOOR || hypeScore > HYPE_CEILING) revert PA_HypeRange();
        events[eventId].hypeScore = hypeScore;
        emit HypeSet(eventId, hypeScore);
    }

    function epochSnapshot0(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot1(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot2(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot3(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot4(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot5(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot6(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot7(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot8(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot9(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot10(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot11(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot12(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot13(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot14(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot15(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot16(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot17(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot18(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    function epochSnapshot19(uint256 eventId) external view returns (uint64 epochId, uint64 endsAt, uint32 hype) {
        PromEvent storage ev = events[eventId];
        return (ev.currentEpoch, ev.epochEndsAt, ev.hypeScore);
    }

    // ---- split digest views ----
    function digestHalfA(uint256 eventId) public view returns (bytes32 hA) {
        PromEvent storage ev = events[eventId];
        hA = keccak256(abi.encode(
            ev.host,
            ev.themeSeed,
            ev.openedAt,
            ev.guestCount,
            ev.totalPledgedWei,
            DOMAIN_SALT
        ));
    }

    function digestHalfB(uint256 eventId) public view returns (bytes32 hB) {
        PromEvent storage ev = events[eventId];
        hB = keccak256(abi.encode(
            ev.chaperoneCount,
            ev.hypeScore,
            ev.currentEpoch,
            ev.totalSpentWei,
            THEME_ROOT,
            COURT_SALT
        ));
    }

    function eventDigest(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(digestHalfA(eventId), digestHalfB(eventId)));
    }

    function assertEventDigest(uint256 eventId, bytes32 supplied) external view {
        bytes32 computed = keccak256(abi.encodePacked(digestHalfA(eventId), digestHalfB(eventId)));
        if (supplied != computed) revert PA_DigestMismatch(supplied, computed);
    }

    function anchorDigest0(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest1(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest2(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest3(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest4(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest5(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest6(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest7(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest8(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest9(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest10(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest11(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest12(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest13(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest14(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest15(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest16(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest17(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest18(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest19(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest20(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest21(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest22(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest23(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    function anchorDigest24(uint256 eventId) external view returns (bytes32) {
        return keccak256(abi.encodePacked(ADDRESS_A, ADDRESS_B, ADDRESS_C, eventId, uint256({d})));
    }

    // ---- guest & tier views ----
    function guestAtIndex0(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex1(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex2(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex3(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex4(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex5(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex6(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex7(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex8(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex9(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex10(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex11(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex12(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex13(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex14(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex15(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex16(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex17(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex18(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex19(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex20(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex21(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex22(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex23(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex24(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex25(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex26(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex27(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex28(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function guestAtIndex29(uint256 eventId, uint256 index) external view returns (address guest, uint8 tierId, uint256 paidWei) {
        if (index >= guestList[eventId].length) revert PA_NotRsvp(eventId, address(0));
        guest = guestList[eventId][index];
        RsvpRecord storage rec = rsvps[eventId][guest];
        tierId = rec.tierId;
        paidWei = rec.paidWei;
    }

    function tierSnapshot0(uint256 eventId, uint8 tierId) external view returns (uint256 price, uint16 cap, uint16 sold, bool active) {
        TicketTier storage tier = tiers[eventId][tierId];
        return (tier.priceWei, tier.cap, tier.sold, tier.active);
    }

    function tierSnapshot1(uint256 eventId, uint8 tierId) external view returns (uint256 price, uint16 cap, uint16 sold, bool active) {
