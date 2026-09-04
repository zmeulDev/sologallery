# Metadata Search Implementation Plan

## Context
The user wants to extend the search functionality to include EXIF metadata fields (camera make, model, ISO, exposure time, etc.) so users can search for photos based on camera settings and equipment.

## Current Implementation
- Search supports:
  - Metadata search: date (year/month), album name, person name, media type, favorites
  - Content search: ML labels and OCR text (when enabled in settings)
- The search UI has two states: idle (shows browse labels and recently viewed carousel) and results (shows matching albums, people, and photo grid)
- When a query is active (non-empty, non-date, or filters applied), the recently viewed carousel is hidden

## Proposed Changes
1. **Database Schema Update**:
   - Add EXIF columns to the `photo_assets` table:
     - `exif_make TEXT`
     - `exif_model TEXT`
     - `exif_iso TEXT`
     - `exif_exposure_time TEXT`
     - `exif_focal_length TEXT`
     - `exif_aperture TEXT`
   - These will be populated during the metadata sweep.

2. **Metadata Sweep Enhancement**:
   - Update `PhotoLibraryService.libraryMetadataPage` to extract EXIF fields from `AssetEntity.exif`:
     - Make: `entity.exif.imageIfd['Make']`
     - Model: `entity.exif.imageIfd['Model']`
     - ISO: `entity.exif.exifIfd['ISOSpeedRatings']` (or similar)
     - ExposureTime: `entity.exif.exifIfd['ExposureTime']`
     - FocalLength: `entity.exif.exifIfd['FocalLength']`
     - Aperture: `entity.exif.exifIfd['FNumber']`
   - Handle null values and convert to strings appropriately (e.g., using `toString()` for numbers, handling rational types if needed).
   - Extend the return type of `libraryMetadataPage` to include these EXIF fields.
   - Update `IndexingService._sweepMetadata` to pass the EXIF data to `IndexDao.upsertMetadata`.
   - Update the `SweptAsset` typedef in `index_dao.dart` to include the EXIF fields.
   - Update `IndexDao.upsertMetadata` to insert/update the EXIF columns in the `photo_assets` table.

3. **Search Integration**:
   - Modify `IndexDao.searchContent` to include EXIF fields in the search scope:
     - When performing content search (ML labels, OCR text), also match against the EXIF columns using SQLite `LIKE` with `%query%` pattern.
     - This ensures that when content search is enabled, users can search for EXIF values just like they search for ML labels.
   - The search will match on any of: ML labels, OCR text, or EXIF fields (make, model, ISO, exposure time, focal length, aperture).

4. **Search Provider Updates**:
   - No changes needed to `search_providers.dart` if we integrate EXIF into content search, as the `searchAssetsProvider` already uses `IndexDao.searchContent` when `_contentSearch` is true.
   - The `searchEnabledProvider` already controls whether content search is active, so EXIF search will automatically be gated by the same setting.

5. **Testing**:
   - Update unit tests for `IndexDao.searchContent` to verify EXIF matching.
   - Add widget tests to verify that EXIF search works and hides the recently viewed carousel when active.
   - Ensure that the EXIF fields are correctly extracted and stored by updating metadata sweep tests.
   - Test that EXIF data is persisted across app restarts.

6. **Performance Considerations**:
   - Adding columns to `photo_assets` will increase storage slightly but is acceptable.
   - The `LIKE` queries with leading wildcards (`%query%`) cannot use indexes, but since we already use this for ML labels and OCR text, the performance impact is similar.
   - Consider adding indexes on EXIF columns if specific search patterns become common (e.g., prefix searches), but for substring matching, indexes are not helpful.

## Implementation Steps
1. Update database schema (add columns to `photo_assets` table) and generate DAO classes.
2. Enhance `PhotoLibraryService.libraryMetadataPage` to extract EXIF data.
3. Update `IndexingService._sweepMetadata` to handle the extended metadata.
4. Update `SweptAsset` typedef and `IndexDao.upsertMetadata` in `index_dao.dart`.
5. Modify `IndexDao.searchContent` to include EXIF field matching in the search query.
6. Test the changes end-to-end.

## Verification
- Run `tool/check.sh` to ensure no analysis errors and tests pass.
- Manually verify on a device that:
  - EXIF data is correctly stored in the database after a metadata sweep.
  - Searching for a camera make (e.g., "Canon") returns photos taken with that camera when content search is enabled.
  - The recently viewed carousel hides when an EXIF search query is active.
  - Searching for EXIF fields works in combination with other filters (media type, favorites, date range).

## Future Work
- Consider adding range searches for numeric EXIF fields (ISO, exposure time, focal length, aperture) if users need more advanced filtering.
- Add EXIF fields to the browse labels in the idle state for quick access to common camera settings.