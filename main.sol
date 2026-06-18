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
