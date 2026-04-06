import Foundation

enum LibArchiveError: Error, LocalizedError {
	case generic(String)
	
	var errorDescription: String? {
		switch self {
		case .generic(let msg): msg
		}
	}
}

class LibArchive: IteratorProtocol, Sequence {
	typealias Element = ArchiveEntry
	
	private var ptr: OpaquePointer?
	private var currentIndex: Int = 0
	/// Number of items in archive
	/// @Note only accurate after all entries have been processed
	var count: Int { currentIndex }
	/// File system size
	let compressedSize: Int64
	/// Uncompressed size of all items
	/// @Note only accurate after all entries have been processed
	var uncompressedSize: Int64 = 0

	init(_ url: URL) throws {
		let path = url.path// url.path(percentEncoded: false)
		compressedSize = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int64 ?? -1
		
		let archive = archive_read_new()
		archive_read_support_filter_all(archive)
		archive_read_support_format_all(archive)
		let r = archive_read_open_filename(archive, path, 4096)
		if (r != ARCHIVE_OK) {
			if let reason = archive_error_string(archive) {
				throw LibArchiveError.generic(String(cString: reason))
			}
			throw LibArchiveError.generic("could not load archive")
		}
		self.ptr = archive
	}
	
	deinit {
		close()
	}
	
	static func version() -> String {
		String(cString: archive_version_string())
	}
	
	/// No need to call manually, will close archive automatically after last entry
	func close() {
		if self.ptr != nil {
			archive_read_free(self.ptr)
			self.ptr = nil
		}
	}
	
	func next() -> ArchiveEntry? {
		var entry: OpaquePointer?
		guard self.ptr != nil, archive_read_next_header(self.ptr, &entry) == ARCHIVE_OK else {
			self.close()
			return nil
		}
		currentIndex += 1
		let typ = Filetype(rawValue: archive_entry_filetype(entry)) ?? .Undefined
		let size = Int64(archive_entry_size(entry))
		uncompressedSize += size
		return ArchiveEntry(
			index: currentIndex - 1,
			path: String(cString: archive_entry_pathname(entry)),
			size: typ == .Directory ? -1 : size,
			perm: Perm(raw: archive_entry_perm(entry)),
			filetype: typ,
			modified: archive_entry_mtime(entry),
		)
	}
}

struct ArchiveEntry {
	let index: Int
	let path: String
	let size: Int64
	let perm: Perm
	let filetype: Filetype
	let modified: time_t
}

struct Perm: CustomDebugStringConvertible {
	let raw: mode_t
	
	var setuid: Bool { raw & 0o4000 != 0 }
	var setgid: Bool { raw & 0o2000 != 0 }
	var sticky: Bool { raw & 0o1000 != 0 }
	var owner: UInt8 { UInt8(raw >> 6 & 7) }
	var group: UInt8 { UInt8(raw >> 3 & 7) }
	var other: UInt8 { UInt8(raw & 7) }
	
	var str: String { String(raw, radix: 8) }
	var debugDescription: String { str }
}

// for whatever reason we cannot use `AE_IFDIR` etc.
enum Filetype: mode_t {
	case Undefined       = 0o0000000
	case RegularFile     = 0o0100000
	case SymbolicLink    = 0o0120000
	case Socket          = 0o0140000
	case CharacterDevice = 0o0020000
	case BlockDevice     = 0o0060000
	case Directory       = 0o0040000
	case NamedPipe       = 0o0010000
}
