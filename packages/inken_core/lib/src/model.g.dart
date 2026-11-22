// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Stroke _$StrokeFromJson(Map<String, dynamic> json) => Stroke(
  id: json['id'] as String,
  tool: $enumDecode(_$InkToolEnumMap, json['tool']),
  color: (json['color'] as num).toInt(),
  width: (json['width'] as num).toDouble(),
  points: const InkPointsConverter().fromJson(json['points'] as List),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$StrokeToJson(Stroke instance) => <String, dynamic>{
  'id': instance.id,
  'tool': _$InkToolEnumMap[instance.tool]!,
  'color': instance.color,
  'width': instance.width,
  'points': const InkPointsConverter().toJson(instance.points),
  'type': instance.$type,
};

const _$InkToolEnumMap = {
  InkTool.pen: 'pen',
  InkTool.highlighter: 'highlighter',
};

Shape _$ShapeFromJson(Map<String, dynamic> json) => Shape(
  id: json['id'] as String,
  kind: $enumDecode(_$ShapeKindEnumMap, json['kind']),
  color: (json['color'] as num).toInt(),
  width: (json['width'] as num).toDouble(),
  x1: (json['x1'] as num).toDouble(),
  y1: (json['y1'] as num).toDouble(),
  x2: (json['x2'] as num).toDouble(),
  y2: (json['y2'] as num).toDouble(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ShapeToJson(Shape instance) => <String, dynamic>{
  'id': instance.id,
  'kind': _$ShapeKindEnumMap[instance.kind]!,
  'color': instance.color,
  'width': instance.width,
  'x1': instance.x1,
  'y1': instance.y1,
  'x2': instance.x2,
  'y2': instance.y2,
  'type': instance.$type,
};

const _$ShapeKindEnumMap = {
  ShapeKind.line: 'line',
  ShapeKind.arrow: 'arrow',
  ShapeKind.rectangle: 'rectangle',
  ShapeKind.ellipse: 'ellipse',
  ShapeKind.coordinate: 'coordinate',
};

TextItem _$TextItemFromJson(Map<String, dynamic> json) => TextItem(
  id: json['id'] as String,
  text: json['text'] as String,
  color: (json['color'] as num).toInt(),
  fontSize: (json['fontSize'] as num).toDouble(),
  x: (json['x'] as num).toDouble(),
  y: (json['y'] as num).toDouble(),
  width: (json['width'] as num).toDouble(),
  height: (json['height'] as num).toDouble(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$TextItemToJson(TextItem instance) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'color': instance.color,
  'fontSize': instance.fontSize,
  'x': instance.x,
  'y': instance.y,
  'width': instance.width,
  'height': instance.height,
  'type': instance.$type,
};

ImageItem _$ImageItemFromJson(Map<String, dynamic> json) => ImageItem(
  id: json['id'] as String,
  imageId: json['imageId'] as String,
  x: (json['x'] as num).toDouble(),
  y: (json['y'] as num).toDouble(),
  width: (json['width'] as num).toDouble(),
  height: (json['height'] as num).toDouble(),
  opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
  rotation: (json['rotation'] as num?)?.toInt() ?? 0,
  cropLeft: (json['cropLeft'] as num?)?.toDouble() ?? 0.0,
  cropTop: (json['cropTop'] as num?)?.toDouble() ?? 0.0,
  cropRight: (json['cropRight'] as num?)?.toDouble() ?? 1.0,
  cropBottom: (json['cropBottom'] as num?)?.toDouble() ?? 1.0,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ImageItemToJson(ImageItem instance) => <String, dynamic>{
  'id': instance.id,
  'imageId': instance.imageId,
  'x': instance.x,
  'y': instance.y,
  'width': instance.width,
  'height': instance.height,
  'opacity': instance.opacity,
  'rotation': instance.rotation,
  'cropLeft': instance.cropLeft,
  'cropTop': instance.cropTop,
  'cropRight': instance.cropRight,
  'cropBottom': instance.cropBottom,
  'type': instance.$type,
};

_PageLayer _$PageLayerFromJson(Map<String, dynamic> json) => _PageLayer(
  sourceIndex: (json['sourceIndex'] as num?)?.toInt(),
  template: $enumDecodeNullable(_$PageTemplateEnumMap, json['template']),
  color: $enumDecodeNullable(_$PageColorEnumMap, json['color']),
  width: (json['width'] as num).toDouble(),
  height: (json['height'] as num).toDouble(),
  rotation: (json['rotation'] as num?)?.toInt(),
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => InkItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <InkItem>[],
);

Map<String, dynamic> _$PageLayerToJson(_PageLayer instance) =>
    <String, dynamic>{
      'sourceIndex': ?instance.sourceIndex,
      'template': ?_$PageTemplateEnumMap[instance.template],
      'color': ?_$PageColorEnumMap[instance.color],
      'width': instance.width,
      'height': instance.height,
      'rotation': ?instance.rotation,
      'items': instance.items.map((e) => e.toJson()).toList(),
    };

const _$PageTemplateEnumMap = {
  PageTemplate.blank: 'blank',
  PageTemplate.grid: 'grid',
  PageTemplate.dotted: 'dotted',
  PageTemplate.lined: 'lined',
  PageTemplate.coordinate: 'coordinate',
};

const _$PageColorEnumMap = {
  PageColor.white: 'white',
  PageColor.black: 'black',
  PageColor.straw: 'straw',
};

_InkenDocument _$InkenDocumentFromJson(Map<String, dynamic> json) =>
    _InkenDocument(
      formatVersion:
          (json['formatVersion'] as num?)?.toInt() ?? currentFormatVersion,
      pages:
          (json['pages'] as List<dynamic>?)
              ?.map((e) => PageLayer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PageLayer>[],
    );

Map<String, dynamic> _$InkenDocumentToJson(_InkenDocument instance) =>
    <String, dynamic>{
      'formatVersion': instance.formatVersion,
      'pages': instance.pages.map((e) => e.toJson()).toList(),
    };
