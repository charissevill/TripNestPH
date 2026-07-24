/// Standard lifecycle for any screen/ViewModel backed by an async data
/// source, used consistently across the app to drive loading spinners,
/// empty states and error banners without ad-hoc booleans per screen.
enum ViewStatus { initial, loading, loaded, empty, error }
