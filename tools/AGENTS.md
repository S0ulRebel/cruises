# Authoring tools

Tools never run through game flags or runtime imports. An output-producing command
requires an explicit destination owned by the caller. Target one asset/outfit, never
rebuild all scenes. Preserve source models and designer-authored scene transforms.
Reports/check modes may be read-only. Diagnostic outputs use unique run directories.
