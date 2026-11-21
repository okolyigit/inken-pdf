// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
InkItem _$InkItemFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'stroke':
          return Stroke.fromJson(
            json
          );
                case 'shape':
          return Shape.fromJson(
            json
          );
                case 'text':
          return TextItem.fromJson(
            json
          );
                case 'image':
          return ImageItem.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'InkItem',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$InkItem {

 String get id; double get width;
/// Create a copy of InkItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InkItemCopyWith<InkItem> get copyWith => _$InkItemCopyWithImpl<InkItem>(this as InkItem, _$identity);

  /// Serializes this InkItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as InkItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InkItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.width, _this.width) || other.width == _this.width));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as InkItem;
  return Object.hash(runtimeType,_this.id,_this.width);
}

@override
String toString() {
  final _this = this as InkItem;
  return 'InkItem(id: ${_this.id}, width: ${_this.width})';
}


}

/// @nodoc
abstract mixin class $InkItemCopyWith<$Res>  {
  factory $InkItemCopyWith(InkItem value, $Res Function(InkItem) _then) = _$InkItemCopyWithImpl;
@useResult
$Res call({
 String id, double width
});




}
/// @nodoc
class _$InkItemCopyWithImpl<$Res>
    implements $InkItemCopyWith<$Res> {
  _$InkItemCopyWithImpl(this._self, this._then);

  final InkItem _self;
  final $Res Function(InkItem) _then;

/// Create a copy of InkItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? width = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [InkItem].
extension InkItemPatterns on InkItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Stroke value)?  stroke,TResult Function( Shape value)?  shape,TResult Function( TextItem value)?  text,TResult Function( ImageItem value)?  image,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Stroke() when stroke != null:
return stroke(_that);case Shape() when shape != null:
return shape(_that);case TextItem() when text != null:
return text(_that);case ImageItem() when image != null:
return image(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Stroke value)  stroke,required TResult Function( Shape value)  shape,required TResult Function( TextItem value)  text,required TResult Function( ImageItem value)  image,}){
final _that = this;
switch (_that) {
case Stroke():
return stroke(_that);case Shape():
return shape(_that);case TextItem():
return text(_that);case ImageItem():
return image(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Stroke value)?  stroke,TResult? Function( Shape value)?  shape,TResult? Function( TextItem value)?  text,TResult? Function( ImageItem value)?  image,}){
final _that = this;
switch (_that) {
case Stroke() when stroke != null:
return stroke(_that);case Shape() when shape != null:
return shape(_that);case TextItem() when text != null:
return text(_that);case ImageItem() when image != null:
return image(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  InkTool tool,  int color,  double width, @InkPointsConverter()  List<InkPoint> points)?  stroke,TResult Function( String id,  ShapeKind kind,  int color,  double width,  double x1,  double y1,  double x2,  double y2)?  shape,TResult Function( String id,  String text,  int color,  double fontSize,  double x,  double y,  double width,  double height)?  text,TResult Function( String id,  String imageId,  double x,  double y,  double width,  double height)?  image,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Stroke() when stroke != null:
return stroke(_that.id,_that.tool,_that.color,_that.width,_that.points);case Shape() when shape != null:
return shape(_that.id,_that.kind,_that.color,_that.width,_that.x1,_that.y1,_that.x2,_that.y2);case TextItem() when text != null:
return text(_that.id,_that.text,_that.color,_that.fontSize,_that.x,_that.y,_that.width,_that.height);case ImageItem() when image != null:
return image(_that.id,_that.imageId,_that.x,_that.y,_that.width,_that.height);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  InkTool tool,  int color,  double width, @InkPointsConverter()  List<InkPoint> points)  stroke,required TResult Function( String id,  ShapeKind kind,  int color,  double width,  double x1,  double y1,  double x2,  double y2)  shape,required TResult Function( String id,  String text,  int color,  double fontSize,  double x,  double y,  double width,  double height)  text,required TResult Function( String id,  String imageId,  double x,  double y,  double width,  double height)  image,}) {final _that = this;
switch (_that) {
case Stroke():
return stroke(_that.id,_that.tool,_that.color,_that.width,_that.points);case Shape():
return shape(_that.id,_that.kind,_that.color,_that.width,_that.x1,_that.y1,_that.x2,_that.y2);case TextItem():
return text(_that.id,_that.text,_that.color,_that.fontSize,_that.x,_that.y,_that.width,_that.height);case ImageItem():
return image(_that.id,_that.imageId,_that.x,_that.y,_that.width,_that.height);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  InkTool tool,  int color,  double width, @InkPointsConverter()  List<InkPoint> points)?  stroke,TResult? Function( String id,  ShapeKind kind,  int color,  double width,  double x1,  double y1,  double x2,  double y2)?  shape,TResult? Function( String id,  String text,  int color,  double fontSize,  double x,  double y,  double width,  double height)?  text,TResult? Function( String id,  String imageId,  double x,  double y,  double width,  double height)?  image,}) {final _that = this;
switch (_that) {
case Stroke() when stroke != null:
return stroke(_that.id,_that.tool,_that.color,_that.width,_that.points);case Shape() when shape != null:
return shape(_that.id,_that.kind,_that.color,_that.width,_that.x1,_that.y1,_that.x2,_that.y2);case TextItem() when text != null:
return text(_that.id,_that.text,_that.color,_that.fontSize,_that.x,_that.y,_that.width,_that.height);case ImageItem() when image != null:
return image(_that.id,_that.imageId,_that.x,_that.y,_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class Stroke implements InkItem {
  const Stroke({required this.id, required this.tool, required this.color, required this.width, @InkPointsConverter() required  List<InkPoint> points,  String? $type}): _points = points,$type = $type ?? 'stroke';
  factory Stroke.fromJson(Map<String, dynamic> json) => _$StrokeFromJson(json);

@override final  String id;
 final  InkTool tool;
 final  int color;
@override final  double width;
 final  List<InkPoint> _points;
@InkPointsConverter() List<InkPoint> get points {
  if (_points is EqualUnmodifiableListView) return _points;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_points);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of InkItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StrokeCopyWith<Stroke> get copyWith => _$StrokeCopyWithImpl<Stroke>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StrokeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Stroke&&(identical(other.id, id) || other.id == id)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.color, color) || other.color == color)&&(identical(other.width, width) || other.width == width)&&const DeepCollectionEquality().equals(other.points, _points));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,tool,color,width,const DeepCollectionEquality().hash(_points));
}

@override
String toString() {
    return 'InkItem.stroke(id: $id, tool: $tool, color: $color, width: $width, points: $points)';
}


}

/// @nodoc
abstract mixin class $StrokeCopyWith<$Res> implements $InkItemCopyWith<$Res> {
  factory $StrokeCopyWith(Stroke value, $Res Function(Stroke) _then) = _$StrokeCopyWithImpl;
@override @useResult
$Res call({
 String id, InkTool tool, int color, double width,@InkPointsConverter() List<InkPoint> points
});




}
/// @nodoc
class _$StrokeCopyWithImpl<$Res>
    implements $StrokeCopyWith<$Res> {
  _$StrokeCopyWithImpl(this._self, this._then);

  final Stroke _self;
  final $Res Function(Stroke) _then;

/// Create a copy of InkItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tool = null,Object? color = null,Object? width = null,Object? points = null,}) {
  return _then(Stroke(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as InkTool,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,points: null == points ? _self._points : points // ignore: cast_nullable_to_non_nullable
as List<InkPoint>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class Shape implements InkItem {
  const Shape({required this.id, required this.kind, required this.color, required this.width, required this.x1, required this.y1, required this.x2, required this.y2,  String? $type}): $type = $type ?? 'shape';
  factory Shape.fromJson(Map<String, dynamic> json) => _$ShapeFromJson(json);

@override final  String id;
 final  ShapeKind kind;
 final  int color;
@override final  double width;
 final  double x1;
 final  double y1;
 final  double x2;
 final  double y2;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of InkItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShapeCopyWith<Shape> get copyWith => _$ShapeCopyWithImpl<Shape>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShapeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Shape&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.color, color) || other.color == color)&&(identical(other.width, width) || other.width == width)&&(identical(other.x1, x1) || other.x1 == x1)&&(identical(other.y1, y1) || other.y1 == y1)&&(identical(other.x2, x2) || other.x2 == x2)&&(identical(other.y2, y2) || other.y2 == y2));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,kind,color,width,x1,y1,x2,y2);
}

@override
String toString() {
    return 'InkItem.shape(id: $id, kind: $kind, color: $color, width: $width, x1: $x1, y1: $y1, x2: $x2, y2: $y2)';
}


}

/// @nodoc
abstract mixin class $ShapeCopyWith<$Res> implements $InkItemCopyWith<$Res> {
  factory $ShapeCopyWith(Shape value, $Res Function(Shape) _then) = _$ShapeCopyWithImpl;
@override @useResult
$Res call({
 String id, ShapeKind kind, int color, double width, double x1, double y1, double x2, double y2
});




}
/// @nodoc
class _$ShapeCopyWithImpl<$Res>
    implements $ShapeCopyWith<$Res> {
  _$ShapeCopyWithImpl(this._self, this._then);

  final Shape _self;
  final $Res Function(Shape) _then;

/// Create a copy of InkItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? color = null,Object? width = null,Object? x1 = null,Object? y1 = null,Object? x2 = null,Object? y2 = null,}) {
  return _then(Shape(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ShapeKind,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,x1: null == x1 ? _self.x1 : x1 // ignore: cast_nullable_to_non_nullable
as double,y1: null == y1 ? _self.y1 : y1 // ignore: cast_nullable_to_non_nullable
as double,x2: null == x2 ? _self.x2 : x2 // ignore: cast_nullable_to_non_nullable
as double,y2: null == y2 ? _self.y2 : y2 // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
@JsonSerializable()

class TextItem implements InkItem {
  const TextItem({required this.id, required this.text, required this.color, required this.fontSize, required this.x, required this.y, required this.width, required this.height,  String? $type}): $type = $type ?? 'text';
  factory TextItem.fromJson(Map<String, dynamic> json) => _$TextItemFromJson(json);

@override final  String id;
 final  String text;
 final  int color;
 final  double fontSize;
 final  double x;
 final  double y;
@override final  double width;
 final  double height;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of InkItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextItemCopyWith<TextItem> get copyWith => _$TextItemCopyWithImpl<TextItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TextItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TextItem&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.color, color) || other.color == color)&&(identical(other.fontSize, fontSize) || other.fontSize == fontSize)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,text,color,fontSize,x,y,width,height);
}

@override
String toString() {
    return 'InkItem.text(id: $id, text: $text, color: $color, fontSize: $fontSize, x: $x, y: $y, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $TextItemCopyWith<$Res> implements $InkItemCopyWith<$Res> {
  factory $TextItemCopyWith(TextItem value, $Res Function(TextItem) _then) = _$TextItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String text, int color, double fontSize, double x, double y, double width, double height
});




}
/// @nodoc
class _$TextItemCopyWithImpl<$Res>
    implements $TextItemCopyWith<$Res> {
  _$TextItemCopyWithImpl(this._self, this._then);

  final TextItem _self;
  final $Res Function(TextItem) _then;

/// Create a copy of InkItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = null,Object? color = null,Object? fontSize = null,Object? x = null,Object? y = null,Object? width = null,Object? height = null,}) {
  return _then(TextItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ImageItem implements InkItem {
  const ImageItem({required this.id, required this.imageId, required this.x, required this.y, required this.width, required this.height,  String? $type}): $type = $type ?? 'image';
  factory ImageItem.fromJson(Map<String, dynamic> json) => _$ImageItemFromJson(json);

@override final  String id;
 final  String imageId;
 final  double x;
 final  double y;
@override final  double width;
 final  double height;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of InkItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageItemCopyWith<ImageItem> get copyWith => _$ImageItemCopyWithImpl<ImageItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ImageItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageItem&&(identical(other.id, id) || other.id == id)&&(identical(other.imageId, imageId) || other.imageId == imageId)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,imageId,x,y,width,height);
}

@override
String toString() {
    return 'InkItem.image(id: $id, imageId: $imageId, x: $x, y: $y, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $ImageItemCopyWith<$Res> implements $InkItemCopyWith<$Res> {
  factory $ImageItemCopyWith(ImageItem value, $Res Function(ImageItem) _then) = _$ImageItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String imageId, double x, double y, double width, double height
});




}
/// @nodoc
class _$ImageItemCopyWithImpl<$Res>
    implements $ImageItemCopyWith<$Res> {
  _$ImageItemCopyWithImpl(this._self, this._then);

  final ImageItem _self;
  final $Res Function(ImageItem) _then;

/// Create a copy of InkItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? imageId = null,Object? x = null,Object? y = null,Object? width = null,Object? height = null,}) {
  return _then(ImageItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,imageId: null == imageId ? _self.imageId : imageId // ignore: cast_nullable_to_non_nullable
as String,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$PageLayer {

 int? get sourceIndex; PageTemplate? get template; PageColor? get color; double get width; double get height; int? get rotation; List<InkItem> get items;
/// Create a copy of PageLayer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PageLayerCopyWith<PageLayer> get copyWith => _$PageLayerCopyWithImpl<PageLayer>(this as PageLayer, _$identity);

  /// Serializes this PageLayer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PageLayer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PageLayer&&(identical(other.sourceIndex, _this.sourceIndex) || other.sourceIndex == _this.sourceIndex)&&(identical(other.template, _this.template) || other.template == _this.template)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.rotation, _this.rotation) || other.rotation == _this.rotation)&&const DeepCollectionEquality().equals(other.items, _this.items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PageLayer;
  return Object.hash(runtimeType,_this.sourceIndex,_this.template,_this.color,_this.width,_this.height,_this.rotation,const DeepCollectionEquality().hash(_this.items));
}

@override
String toString() {
  final _this = this as PageLayer;
  return 'PageLayer(sourceIndex: ${_this.sourceIndex}, template: ${_this.template}, color: ${_this.color}, width: ${_this.width}, height: ${_this.height}, rotation: ${_this.rotation}, items: ${_this.items})';
}


}

/// @nodoc
abstract mixin class $PageLayerCopyWith<$Res>  {
  factory $PageLayerCopyWith(PageLayer value, $Res Function(PageLayer) _then) = _$PageLayerCopyWithImpl;
@useResult
$Res call({
 int? sourceIndex, PageTemplate? template, PageColor? color, double width, double height, int? rotation, List<InkItem> items
});




}
/// @nodoc
class _$PageLayerCopyWithImpl<$Res>
    implements $PageLayerCopyWith<$Res> {
  _$PageLayerCopyWithImpl(this._self, this._then);

  final PageLayer _self;
  final $Res Function(PageLayer) _then;

/// Create a copy of PageLayer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceIndex = freezed,Object? template = freezed,Object? color = freezed,Object? width = null,Object? height = null,Object? rotation = freezed,Object? items = null,}) {
  return _then(PageLayer(
sourceIndex: freezed == sourceIndex ? _self.sourceIndex : sourceIndex // ignore: cast_nullable_to_non_nullable
as int?,template: freezed == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as PageTemplate?,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as PageColor?,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,rotation: freezed == rotation ? _self.rotation : rotation // ignore: cast_nullable_to_non_nullable
as int?,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<InkItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [PageLayer].
extension PageLayerPatterns on PageLayer {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PageLayer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PageLayer() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PageLayer value)  $default,){
final _that = this;
switch (_that) {
case _PageLayer():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PageLayer value)?  $default,){
final _that = this;
switch (_that) {
case _PageLayer() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? sourceIndex,  PageTemplate? template,  PageColor? color,  double width,  double height,  int? rotation,  List<InkItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PageLayer() when $default != null:
return $default(_that.sourceIndex,_that.template,_that.color,_that.width,_that.height,_that.rotation,_that.items);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? sourceIndex,  PageTemplate? template,  PageColor? color,  double width,  double height,  int? rotation,  List<InkItem> items)  $default,) {final _that = this;
switch (_that) {
case _PageLayer():
return $default(_that.sourceIndex,_that.template,_that.color,_that.width,_that.height,_that.rotation,_that.items);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? sourceIndex,  PageTemplate? template,  PageColor? color,  double width,  double height,  int? rotation,  List<InkItem> items)?  $default,) {final _that = this;
switch (_that) {
case _PageLayer() when $default != null:
return $default(_that.sourceIndex,_that.template,_that.color,_that.width,_that.height,_that.rotation,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PageLayer extends PageLayer {
  const _PageLayer({this.sourceIndex, this.template, this.color, required this.width, required this.height, this.rotation,  List<InkItem> items = const <InkItem>[]}): _items = items,super._();
  factory _PageLayer.fromJson(Map<String, dynamic> json) => _$PageLayerFromJson(json);

@override final  int? sourceIndex;
@override final  PageTemplate? template;
@override final  PageColor? color;
@override final  double width;
@override final  double height;
@override final  int? rotation;
 final  List<InkItem> _items;
@override@JsonKey() List<InkItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of PageLayer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PageLayerCopyWith<_PageLayer> get copyWith => __$PageLayerCopyWithImpl<_PageLayer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PageLayerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PageLayer&&(identical(other.sourceIndex, sourceIndex) || other.sourceIndex == sourceIndex)&&(identical(other.template, template) || other.template == template)&&(identical(other.color, color) || other.color == color)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.rotation, rotation) || other.rotation == rotation)&&const DeepCollectionEquality().equals(other.items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sourceIndex,template,color,width,height,rotation,const DeepCollectionEquality().hash(_items));
}

@override
String toString() {
    return 'PageLayer(sourceIndex: $sourceIndex, template: $template, color: $color, width: $width, height: $height, rotation: $rotation, items: $items)';
}


}

/// @nodoc
abstract mixin class _$PageLayerCopyWith<$Res> implements $PageLayerCopyWith<$Res> {
  factory _$PageLayerCopyWith(_PageLayer value, $Res Function(_PageLayer) _then) = __$PageLayerCopyWithImpl;
@override @useResult
$Res call({
 int? sourceIndex, PageTemplate? template, PageColor? color, double width, double height, int? rotation, List<InkItem> items
});




}
/// @nodoc
class __$PageLayerCopyWithImpl<$Res>
    implements _$PageLayerCopyWith<$Res> {
  __$PageLayerCopyWithImpl(this._self, this._then);

  final _PageLayer _self;
  final $Res Function(_PageLayer) _then;

/// Create a copy of PageLayer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceIndex = freezed,Object? template = freezed,Object? color = freezed,Object? width = null,Object? height = null,Object? rotation = freezed,Object? items = null,}) {
  return _then(_PageLayer(
sourceIndex: freezed == sourceIndex ? _self.sourceIndex : sourceIndex // ignore: cast_nullable_to_non_nullable
as int?,template: freezed == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as PageTemplate?,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as PageColor?,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,rotation: freezed == rotation ? _self.rotation : rotation // ignore: cast_nullable_to_non_nullable
as int?,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<InkItem>,
  ));
}


}


/// @nodoc
mixin _$InkenDocument {

 int get formatVersion; List<PageLayer> get pages;
/// Create a copy of InkenDocument
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InkenDocumentCopyWith<InkenDocument> get copyWith => _$InkenDocumentCopyWithImpl<InkenDocument>(this as InkenDocument, _$identity);

  /// Serializes this InkenDocument to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as InkenDocument;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InkenDocument&&(identical(other.formatVersion, _this.formatVersion) || other.formatVersion == _this.formatVersion)&&const DeepCollectionEquality().equals(other.pages, _this.pages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as InkenDocument;
  return Object.hash(runtimeType,_this.formatVersion,const DeepCollectionEquality().hash(_this.pages));
}

@override
String toString() {
  final _this = this as InkenDocument;
  return 'InkenDocument(formatVersion: ${_this.formatVersion}, pages: ${_this.pages})';
}


}

/// @nodoc
abstract mixin class $InkenDocumentCopyWith<$Res>  {
  factory $InkenDocumentCopyWith(InkenDocument value, $Res Function(InkenDocument) _then) = _$InkenDocumentCopyWithImpl;
@useResult
$Res call({
 int formatVersion, List<PageLayer> pages
});




}
/// @nodoc
class _$InkenDocumentCopyWithImpl<$Res>
    implements $InkenDocumentCopyWith<$Res> {
  _$InkenDocumentCopyWithImpl(this._self, this._then);

  final InkenDocument _self;
  final $Res Function(InkenDocument) _then;

/// Create a copy of InkenDocument
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? formatVersion = null,Object? pages = null,}) {
  return _then(InkenDocument(
formatVersion: null == formatVersion ? _self.formatVersion : formatVersion // ignore: cast_nullable_to_non_nullable
as int,pages: null == pages ? _self.pages : pages // ignore: cast_nullable_to_non_nullable
as List<PageLayer>,
  ));
}

}


/// Adds pattern-matching-related methods to [InkenDocument].
extension InkenDocumentPatterns on InkenDocument {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InkenDocument value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InkenDocument() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InkenDocument value)  $default,){
final _that = this;
switch (_that) {
case _InkenDocument():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InkenDocument value)?  $default,){
final _that = this;
switch (_that) {
case _InkenDocument() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int formatVersion,  List<PageLayer> pages)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InkenDocument() when $default != null:
return $default(_that.formatVersion,_that.pages);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int formatVersion,  List<PageLayer> pages)  $default,) {final _that = this;
switch (_that) {
case _InkenDocument():
return $default(_that.formatVersion,_that.pages);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int formatVersion,  List<PageLayer> pages)?  $default,) {final _that = this;
switch (_that) {
case _InkenDocument() when $default != null:
return $default(_that.formatVersion,_that.pages);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InkenDocument extends InkenDocument {
  const _InkenDocument({this.formatVersion = currentFormatVersion,  List<PageLayer> pages = const <PageLayer>[]}): _pages = pages,super._();
  factory _InkenDocument.fromJson(Map<String, dynamic> json) => _$InkenDocumentFromJson(json);

@override@JsonKey() final  int formatVersion;
 final  List<PageLayer> _pages;
@override@JsonKey() List<PageLayer> get pages {
  if (_pages is EqualUnmodifiableListView) return _pages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pages);
}


/// Create a copy of InkenDocument
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InkenDocumentCopyWith<_InkenDocument> get copyWith => __$InkenDocumentCopyWithImpl<_InkenDocument>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InkenDocumentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InkenDocument&&(identical(other.formatVersion, formatVersion) || other.formatVersion == formatVersion)&&const DeepCollectionEquality().equals(other.pages, _pages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,formatVersion,const DeepCollectionEquality().hash(_pages));
}

@override
String toString() {
    return 'InkenDocument(formatVersion: $formatVersion, pages: $pages)';
}


}

/// @nodoc
abstract mixin class _$InkenDocumentCopyWith<$Res> implements $InkenDocumentCopyWith<$Res> {
  factory _$InkenDocumentCopyWith(_InkenDocument value, $Res Function(_InkenDocument) _then) = __$InkenDocumentCopyWithImpl;
@override @useResult
$Res call({
 int formatVersion, List<PageLayer> pages
});




}
/// @nodoc
class __$InkenDocumentCopyWithImpl<$Res>
    implements _$InkenDocumentCopyWith<$Res> {
  __$InkenDocumentCopyWithImpl(this._self, this._then);

  final _InkenDocument _self;
  final $Res Function(_InkenDocument) _then;

/// Create a copy of InkenDocument
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? formatVersion = null,Object? pages = null,}) {
  return _then(_InkenDocument(
formatVersion: null == formatVersion ? _self.formatVersion : formatVersion // ignore: cast_nullable_to_non_nullable
as int,pages: null == pages ? _self._pages : pages // ignore: cast_nullable_to_non_nullable
as List<PageLayer>,
  ));
}


}

// dart format on
