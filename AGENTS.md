## Imported Claude Cowork project instructions

Here is the code repository for a SwiftUI app I have made for budgetting my personal finance each week. Solely for my iphone

## Cloud completion

Ticking a transaction is handled by `public.complete_finance_transaction`. Change that behavior in the Supabase function, not in the app. The app only sends the transaction id, whether to add cash-flow items, the extra cost, and the split names.

## Cloud session import

Importing CoachPlanner sessions is handled by `public.coaching_sessions_for_finance` and `public.import_coaching_sessions_to_finance`. Change that behavior in the Supabase functions, not in the app. The app previews one week, then asks the import function to add sessions that are not already imported.

## Cloud week reset

Resetting the week is `public.reset_finance_week`. Initializing the week is `public.reinitialize_finance_week`. Change that behavior in the Supabase functions, not in the app. The app pushes pending edits, calls the function, then pulls. Initialize sends today's weekday for a predefined row that has no day, and it does not call the function when this phone has no live predefined rows.

## Quick add

Quick add is gone. The app does not read or write `finance_quick_add_transactions`. `Backend/migrations/2026-10-21_drop_finance_quick_add.sql` recreates the week functions without that table and then drops it. Do not apply that file until this build is installed.
