import CoreData
import SwiftData

#if DEBUG
enum CloudKitSchemaInitializer {
    static func initialize(
        configuration: ModelConfiguration,
        containerIdentifier: String,
        modelTypes: [any PersistentModel.Type]
    ) throws {
        try autoreleasepool {
            guard let managedObjectModel = NSManagedObjectModel
                .makeManagedObjectModel(for: modelTypes)
            else { return }

            let description = NSPersistentStoreDescription(
                url: configuration.url
            )
            description.cloudKitContainerOptions =
                NSPersistentCloudKitContainerOptions(
                    containerIdentifier: containerIdentifier
                )
            description.shouldAddStoreAsynchronously = false

            let container = NSPersistentCloudKitContainer(
                name: "shengci",
                managedObjectModel: managedObjectModel
            )
            container.persistentStoreDescriptions = [description]
            var loadError: Error?
            container.loadPersistentStores { _, error in
                loadError = error
            }
            if let loadError {
                throw loadError
            }
            try container.initializeCloudKitSchema()
            if let store = container.persistentStoreCoordinator
                .persistentStores.first
            {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
    }
}
#endif
