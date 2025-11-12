# Discussion Reply System Implementation - Phase 1

## Overview
This document outlines the complete implementation of the Discussion Reply System for the Canvas LMS clone. The system supports threaded discussions with nested replies, edit tracking, soft deletes, and proper authorization.

## Implementation Summary

### 1. Database Schema Changes

#### New Migrations Created:
- **`2025_10_27_000001_add_fields_to_discussion_replies_table.php`**
  - Added `edited_at` (timestamp, nullable) - Tracks when a reply was last edited
  - Added `is_deleted` (boolean, default false) - Soft delete flag for threading preservation

- **`2025_10_27_000002_add_is_locked_to_discussions_table.php`**
  - Added `is_locked` (boolean, default false) - Prevents new replies when discussion is locked

### 2. Model Updates

#### DiscussionReply Model (`app/Models/DiscussionReply.php`)
**New Fields:**
- `edited_at` - Timestamp for edit tracking
- `is_deleted` - Boolean for soft deletes

**New Relationships:**
- `children()` - Recursive relationship for nested replies with eager loading

**New Scopes:**
- `notDeleted()` - Filters out soft-deleted replies

**New Methods:**
- `isEdited()` - Returns true if reply has been edited
- `canEdit($user)` - Checks if user can edit (owns reply and discussion not locked)
- `canDelete($user)` - Checks if user can delete (owns reply OR is instructor)
- `getReplyCountAttribute()` - Computed attribute for child reply count

#### Discussion Model (`app/Models/Discussion.php`)
**New Fields:**
- `is_locked` - Boolean to lock discussions from new replies

**New Casts:**
- `is_pinned` => 'boolean'
- `is_locked` => 'boolean'

### 3. Form Request Validation

#### StoreDiscussionReplyRequest (`app/Http/Requests/Api/StoreDiscussionReplyRequest.php`)
**Authorization:**
- Verifies user is enrolled in course OR is instructor
- Ensures discussion belongs to course

**Validation Rules:**
- `content` - Required, string, min 10 chars, max 10,000 chars
- `parent_id` - Optional, must exist in discussion_replies table

**Custom Validation:**
- Checks discussion is not locked
- Validates parent reply belongs to same discussion
- Prevents replying to deleted comments

#### UpdateDiscussionReplyRequest (`app/Http/Requests/Api/UpdateDiscussionReplyRequest.php`)
**Authorization:**
- User must own the reply
- Ensures reply belongs to discussion and course

**Validation Rules:**
- `content` - Required, string, min 10 chars, max 10,000 chars

**Custom Validation:**
- Checks discussion is not locked
- Prevents editing deleted replies

### 4. Controller Implementation

#### DiscussionReplyController (`app/Http/Controllers/Api/DiscussionReplyController.php`)

**Methods Implemented:**

1. **`index()`** - GET `/api/courses/{course}/discussions/{discussion}/replies`
   - Returns all replies with threaded structure
   - Eager loads user information and nested children
   - Filters out soft-deleted replies
   - Orders by created_at (oldest first)
   - Includes computed fields: `is_edited`, `can_edit`, `can_delete`, `reply_count`
   - Returns total count of non-deleted replies

2. **`store()`** - POST `/api/courses/{course}/discussions/{discussion}/replies`
   - Creates new reply with validation
   - Supports parent_id for threaded replies
   - Tracks unique participants (placeholder for future implementation)
   - Returns created reply with relationships
   - HTTP 201 status on success

3. **`update()`** - PUT `/api/courses/{course}/discussions/{discussion}/replies/{reply}`
   - Updates reply content only
   - Sets `edited_at` timestamp
   - Validates ownership and discussion lock status
   - Returns updated reply with relationships
   - HTTP 200 status on success

4. **`destroy()`** - DELETE `/api/courses/{course}/discussions/{discussion}/replies/{reply}`
   - Implements smart deletion:
     - **Soft delete** if reply has children (preserves threading)
     - **Hard delete** if no children (complete removal)
   - Instructors can delete any reply
   - Users can only delete their own replies
   - HTTP 200 status on success

**Helper Methods:**
- `transformReply()` - Recursively transforms replies with computed fields
- `trackParticipant()` - Placeholder for participant tracking

### 5. API Routes

Added to `routes/api.php` within the `auth:sanctum` middleware group:

```php
Route::prefix('courses/{course}')->group(function () {
    // Discussion reply routes
    Route::get('/discussions/{discussion}/replies', [DiscussionReplyController::class, 'index']);
    Route::post('/discussions/{discussion}/replies', [DiscussionReplyController::class, 'store']);
    Route::put('/discussions/{discussion}/replies/{reply}', [DiscussionReplyController::class, 'update']);
    Route::delete('/discussions/{discussion}/replies/{reply}', [DiscussionReplyController::class, 'destroy']);
});
```

## API Endpoints

### 1. List Replies
**Endpoint:** `GET /api/courses/{course}/discussions/{discussion}/replies`

**Response:**
```json
{
  "replies": [
    {
      "id": 1,
      "discussion_id": 1,
      "user_id": 2,
      "parent_id": null,
      "content": "This is a top-level reply",
      "is_deleted": false,
      "created_at": "2025-10-27T12:00:00.000000Z",
      "updated_at": "2025-10-27T12:00:00.000000Z",
      "edited_at": null,
      "user": {
        "id": 2,
        "name": "John Doe",
        "email": "john@example.com"
      },
      "is_edited": false,
      "can_edit": true,
      "can_delete": true,
      "reply_count": 2,
      "children": [
        {
          "id": 2,
          "parent_id": 1,
          "content": "This is a nested reply",
          ...
        }
      ]
    }
  ],
  "total": 5
}
```

### 2. Create Reply
**Endpoint:** `POST /api/courses/{course}/discussions/{discussion}/replies`

**Request Body:**
```json
{
  "content": "This is my reply to the discussion",
  "parent_id": null  // Optional, for threaded replies
}
```

**Response:** HTTP 201
```json
{
  "message": "Reply posted successfully.",
  "reply": { ... }
}
```

### 3. Update Reply
**Endpoint:** `PUT /api/courses/{course}/discussions/{discussion}/replies/{reply}`

**Request Body:**
```json
{
  "content": "Updated reply content"
}
```

**Response:** HTTP 200
```json
{
  "message": "Reply updated successfully.",
  "reply": { ... }
}
```

### 4. Delete Reply
**Endpoint:** `DELETE /api/courses/{course}/discussions/{discussion}/replies/{reply}`

**Response:** HTTP 200
```json
{
  "message": "Reply deleted successfully."
}
```
or
```json
{
  "message": "Reply marked as deleted."
}
```

## Features Implemented

### ✅ Core Functionality
- [x] Create top-level replies
- [x] Create nested replies (unlimited depth)
- [x] Edit own replies
- [x] Delete own replies
- [x] Instructors can delete any reply
- [x] Threaded structure maintained
- [x] Reply counts accurate
- [x] Locked discussions prevent new replies
- [x] Users cannot edit/delete others' replies (unless instructor)

### ✅ Threading Logic
- [x] Unlimited nesting depth supported
- [x] Parent reply validation
- [x] Recursive relationship loading
- [x] Smart deletion (soft vs hard delete)
- [x] Thread structure preservation

### ✅ Authorization
- [x] User enrollment verification
- [x] Ownership validation for edits/deletes
- [x] Instructor privileges
- [x] Discussion lock enforcement

### ✅ Data Integrity
- [x] Transaction wrapping for safety
- [x] Proper error handling
- [x] Validation messages
- [x] Relationship integrity

### ✅ Response Format
- [x] Nested children structure
- [x] Computed fields (is_edited, can_edit, can_delete, reply_count)
- [x] User information included
- [x] Appropriate HTTP status codes

## Testing Checklist

After implementation, verify the following scenarios work correctly:

### Basic Operations
- [ ] Users can create top-level replies
- [ ] Users can create nested replies (reply to reply)
- [ ] Users can edit their own replies
- [ ] Users can delete their own replies
- [ ] Instructors can delete any reply

### Threading
- [ ] Threaded structure is maintained
- [ ] Reply counts are accurate
- [ ] Nested replies display correctly
- [ ] Deleted parent with children shows as "[This reply has been deleted]"
- [ ] Deleted reply without children is completely removed

### Authorization
- [ ] Locked discussions prevent new replies
- [ ] Locked discussions prevent edits
- [ ] Users cannot edit others' replies
- [ ] Users cannot delete others' replies (unless instructor)
- [ ] Unenrolled users cannot participate

### Edge Cases
- [ ] Cannot reply to deleted comments
- [ ] Cannot edit deleted replies
- [ ] Parent reply must belong to same discussion
- [ ] Content length validation works (10-10,000 chars)
- [ ] Proper error messages for all validation failures

## Files Created/Modified

### Created Files:
1. `database/migrations/2025_10_27_000001_add_fields_to_discussion_replies_table.php`
2. `database/migrations/2025_10_27_000002_add_is_locked_to_discussions_table.php`
3. `app/Http/Requests/Api/StoreDiscussionReplyRequest.php`
4. `app/Http/Requests/Api/UpdateDiscussionReplyRequest.php`
5. `app/Http/Controllers/Api/DiscussionReplyController.php`

### Modified Files:
1. `app/Models/DiscussionReply.php` - Added fields, relationships, scopes, and helper methods
2. `app/Models/Discussion.php` - Added is_locked field and casts
3. `routes/api.php` - Added discussion reply routes

## Future Enhancements (Not Implemented)

The following features were identified but not implemented in Phase 1:

### Participant Tracking
- Track unique participants in discussions
- Update discussion's participant count
- Include participant list in discussion details
- Requires additional database schema (discussion_participants table or JSON field)

### Additional Features
- [ ] Mention support (@username)
- [ ] Attachment support for replies
- [ ] Read/unread tracking
- [ ] Notifications when someone replies to your reply
- [ ] Like/upvote functionality
- [ ] Reply sorting options (newest, oldest, most liked)
- [ ] Pagination for large discussion threads
- [ ] Search within discussion replies

## Notes

- All Intelephense errors in Request classes are false positives (methods inherited from FormRequest)
- The `trackParticipant()` method is a placeholder for future implementation
- Reply count fields on Discussion model are not implemented (can be added later)
- Soft deletes preserve threading structure while hard deletes remove orphaned replies
- All database operations use transactions for data integrity
- Authorization is handled at both Request and Controller levels for security

## Conclusion

The Discussion Reply System Phase 1 implementation is complete and ready for testing. All core functionality has been implemented according to the specifications, with proper validation, authorization, and error handling. The system supports unlimited threading depth and maintains data integrity through smart deletion strategies.