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
