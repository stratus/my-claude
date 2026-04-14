# File Upload & Deserialization — OWASP Security Reference
<!-- Sources: File Upload, Deserialization, XML External Entity Prevention Cheat Sheets -->
<!-- Last synced: 2026-04-14 -->

## Quantified Criteria

### File Upload
- Validate file type server-side by magic bytes, not just extension
- Allowlist permitted extensions; reject everything else
- Rename uploaded files with server-generated names; strip user paths
- Store uploads outside webroot
- Set max file size limit appropriate to use case
- Prohibit: `.asp`, `.jsp`, `.php`, `.js`, `.html`, `.htaccess`, `crossdomain.xml`
- Validate ZIP contents before extraction (path traversal, zip bombs)
- Rewrite images through processing library to strip embedded payloads
- Serve with correct Content-Type and `X-Content-Type-Options: nosniff`

### Deserialization — Dangerous Functions by Language

| Language | Dangerous | Safe Alternative |
|----------|-----------|-----------------|
| Java | `ObjectInputStream.readObject()`, `XMLDecoder`, `XStream.fromXML()` | JSON (Jackson/Gson), XML with safe parser |
| Python | `pickle.load/loads`, `PyYAML.load()`, `jsonpickle` | `json.loads()`, `PyYAML.safe_load()` |
| PHP | `unserialize()` with user input | `json_decode()` |
| .NET | `BinaryFormatter`, `TypeNameHandling` (user-controlled) | `DataContractSerializer`, `XmlSerializer` |
| Ruby | `Marshal.load` with user input | `JSON.parse()` |

### Deserialization Detection Signatures
- Java: hex `AC ED 00 05` or Base64 `rO0`
- .NET: Base64 `AAEAAAD/////` or text `TypeObject`
- Python pickle: ending with `.` or Base64 prefix `gASV`

### XXE Prevention by Language

| Parser / Language | Fix |
|-------------------|-----|
| Java DOM/SAX | `setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)` |
| Java StAX | `setProperty(XMLInputFactory.SUPPORT_DTD, false)` |
| Java JAXB | Route through secure XMLStreamReader with DTD disabled |
| .NET (pre-4.5.2) | `XmlResolver = null` or `DtdProcessing = DtdProcessing.Prohibit` |
| .NET (4.5.2+) | Safe by default |
| Python | Use `defusedxml` package (stdlib vulnerable to Billion Laughs) |
| PHP 8.0+ | Safe by default |
| PHP < 8.0 | `libxml_set_external_entity_loader(null)` |
| C/C++ libxml2 | Avoid `XML_PARSE_NOENT` and `XML_PARSE_DTDLOAD` (safe in 2.9+) |

## Vulnerable Patterns

```python
# BAD: Pickle deserialization of user data
import pickle
data = pickle.loads(request.body)

# GOOD: Use JSON
import json
data = json.loads(request.body)
```

```java
// BAD: Unrestricted deserialization
ObjectInputStream ois = new ObjectInputStream(inputStream);
Object obj = ois.readObject();

// GOOD: Allowlist class filter (Java 9+)
ObjectInputFilter filter = ObjectInputFilter.Config.createFilter("com.myapp.*;!*");
ois.setObjectInputFilter(filter);
```

```python
# BAD: Default XML parser (vulnerable to XXE + Billion Laughs)
from xml.etree import ElementTree
tree = ElementTree.parse(user_uploaded_file)

# GOOD: defusedxml
from defusedxml.ElementTree import parse
tree = parse(user_uploaded_file)
```

## Checklist
- [ ] File type validated by magic bytes server-side (not just extension)
- [ ] Upload filenames regenerated server-side
- [ ] Files stored outside webroot
- [ ] Max file size enforced
- [ ] No dangerous executable extensions accepted
- [ ] No deserialization of untrusted data (pickle, ObjectInputStream, unserialize)
- [ ] If deserialization required: allowlist of permitted classes
- [ ] XML parsing: external entities disabled, DOCTYPE disallowed
- [ ] Python XML: using defusedxml instead of stdlib
- [ ] ZIP extraction validates paths (no `../` traversal)

## Remediation References
- https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html
- ASVS: V12 (Files), V5.5 (Deserialization)
