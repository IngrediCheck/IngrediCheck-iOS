import Foundation

/// Top-level representation of a household returned by the family RPCs.
///
/// Matches the JSON shape produced by the `get_family` and `join_family`
/// Postgres functions (`012_family_functions.sql`), which looks like:
///
/// ```json
/// {
///   "name": "Team Alpha",
///   "selfMember": { ... },
///   "otherMembers": [ { ... } ],
///   "version": 1732736400
/// }
/// ```
struct Family: Codable, Equatable {
    let name: String
    let selfMember: FamilyMember
    var otherMembers: [FamilyMember]
    /// Monotonic version derived from updated_at timestamps in the backend.
    /// Represented as a Unix epoch seconds BIGINT in SQL.
    let version: Int64
}

/// A single member within a family.
///
/// This mirrors the JSON objects built in `get_family` for both
/// `selfMember` and entries in `otherMembers`:
///
/// ```json
/// {
///   "id": "uuid",
///   "name": "Alex Shaw",
///   "color": "#264653",
///   "imageFileHash": "abc123.png",
///   "joined": true
/// }
/// ```
struct FamilyMember: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var color: String
    /// Indicates whether this member already has a user attached
    /// (`user_id IS NOT NULL` in the backend).
    var joined: Bool
    /// Optional hash of the member's avatar image file, if present.
    var imageFileHash: String?
    /// Indicates whether an invite was initiated but deferred ("Maybe later").
    /// Local-only during onboarding; may not be present in backend payloads.
    var invitePending: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case joined
        case imageFileHash
        case invitePending
    }
}

/// Response returned from `POST /ingredicheck/family/invite`.
///
/// The edge function wraps the raw invite code in:
/// `{ "inviteCode": "abc123" }`
struct InviteResponse: Codable, Equatable {
    let inviteCode: String
}


