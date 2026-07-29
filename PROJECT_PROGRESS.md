# Event Management App - Progress Overview

This document tracks the architectural implementation, completed features, and pending tasks for the Event Management Flutter Application built using **Clean Architecture**, **SOLID Principles**, and **Riverpod** state management.

---

## ✅ Completed Features

### 1. Project Scaffolding
- Initialized Flutter application with Clean Architecture folder structure (`core`, `data`, `domain`, `presentation`).
- Integrated Firebase services (`cloud_firestore`, `firebase_auth`, `firebase_core`).
- Added robust state management using `flutter_riverpod` (v3.0 Notifier standards) and `state_notifier`.
- Set up global error handling mapping with a unified `ServerException` architecture.

### 2. Authentication & User Management
- **Domain**: `UserEntity`, `AuthEntity`, `UserRepository`, `AuthRepository`, `LoginUseCase`.
- **Data**: `UserModel`, `AuthModel`, `FirestoreUserRepository`, `FirebaseAuthRepository`.
- **Presentation**: `AuthNotifier` (handles login/state), `RoleBasedRouter` (dynamically routes users to Admin, Staff, or Founder dashboards based on roles).

### 3. Order Management
- **Domain**: `OrderEntity`, `OrderRepository`, `CreateOrderUseCase`, `UpdateOrderUseCase`, `GetOrdersUseCase`, `DeleteOrderUseCase`.
- **Data**: `OrderModel` (with safe JSON/DateTime parsing), `FirestoreOrderRemoteDataSource`, `OrderRepositoryImpl`.
- **Presentation**: `OrderNotifier` (Riverpod state for loading, fetching, updating, creating, and deleting orders).

### 4. Order Item Management
- **Domain**: `OrderItemEntity` (equipped with `copyWith`), `OrderItemRepository`, `AddOrderItemUseCase`, `UpdateOrderItemUseCase`, `GetOrderItemsUseCase`.
- **Data**: `OrderItemModel`, `FirestoreOrderItemRemoteDataSource` (sub-collection pattern or separate query), `OrderItemRepositoryImpl`.
- **Presentation**: `OrderItemNotifier` featuring specialized pure logic such as `toggleCompletion` and `isEventComplete()`.

### 5. Change Request Management
- **Domain**: `ChangeRequestEntity` (with `ChangeStatus` enum), `ChangeRequestRepository`, `CreateChangeRequestUseCase`, `UpdateChangeRequestStatusUseCase`, `GetChangeRequestsByOrderUseCase`.
- **Data**: `ChangeRequestModel`, `FirestoreChangeRequestRemoteDataSource`, `ChangeRequestRepositoryImpl`.
- **Presentation**: `ChangeRequestNotifier` handling state flows for modifications.

### 6. Revisions
- **Domain**: `RevisionEntity` scaffolded with clean architecture entity formatting.

### 7. Inventory Management
- **Domain**: `InventoryItemEntity`, `InventoryRepository` (CRUD operations, stock adjustment logic).
- **Data**: `FirestoreInventoryRepository` mapped to Cloud Firestore `'inventory'`.
- **Presentation**: `InventoryNotifier` (Riverpod notifier managing items, metrics, categories, search filtering), `InventoryManagementScreen`, `AddEditInventoryScreen`.

### 8. Company PDF & Synology NAS Integration
- **Infrastructure**: `SynologyService` (handles Synology Web API authentication, multi-part PDF file upload to Synology FileStation, sharing link generation).
- **Domain & Data**: `CompanyDocumentEntity`, `FirestoreCompanyDocumentRepository` (stores document metadata and Synology download links in Cloud Firestore).
- **PDF Generation**: `CompanyPdfGenerator` (generates official Company Profile PDF with services, contact, terms, and Synology NAS verification stamp).
- **Presentation**: `CompanyDocumentNotifier` & `SynologyCompanyPdfScreen` featuring Synology NAS status configuration, PDF preview, document management, and one-click sharing to clients via system share (`share_plus`).

---

## ⏳ Pending / Remaining Tasks

### 1. Finish Revisions Data Layer
- [ ] Create `RevisionModel` mapping (from/to JSON).
- [ ] Create abstract `RevisionRepository`.
- [ ] Generate `FirestoreRevisionRemoteDataSource` connecting to Firebase. 
- [ ] Implement `RevisionRepositoryImpl`.
- [ ] Create Revision UseCases (e.g., `AddRevisionUseCase`, `GetRevisionsUseCase`).
- [ ] Create `RevisionNotifier` for Riverpod state.

### 2. Dependency Injection / Providers Configuration
- [ ] Create `providers/injection.dart` (or individual provider files like `order_provider.dart`, `item_provider.dart`) to expose all UseCases, Repositories, and Notifiers to the Riverpod graph via `Provider` and `NotifierProvider`.

### 3. UI Layer (Screens & Layouts)
- [x] **Login Screen**: Build out the text fields and logic bindings for Firebase Auth.
- [ ] **Admin/Founder Dashboard**: UI to list all `Orders`, click into them, view `OrderItems`, track ROI, and process `ChangeRequests`.
- [ ] **Staff Dashboard**: A simplified view limiting staff strictly to their `assignedStaffIds` orders, focusing on checking off `OrderItem` units (`toggleCompletion()`).
- [ ] **Forms**: Build out the interfaces for:
  - Creating/Updating Orders.
  - Adding/Updating Items inside an Order.
  - Submitting Change Requests (Staff UI).
  - Approving/Rejecting Change Requests (Admin UI).

### 4. Backend / Security
- [ ] Implement robust Firestore Security Rules matching the `UserRole` limitations. (e.g. Only Founders/Admins can write Orders, Staff can only read/update completion status).
- [ ] Implement Firebase Logout use case and cache clearing.
