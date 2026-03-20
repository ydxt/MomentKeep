import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/product_database_service.dart';

/// ==========================================
/// 地址管理 BLoC
/// ==========================================

abstract class AddressEvent extends Equatable {
  const AddressEvent();

  @override
  List<Object?> get props => [];
}

class LoadAddresses extends AddressEvent {
  final String userId;

  const LoadAddresses(this.userId);

  @override
  List<Object?> get props => [userId];
}

class AddAddress extends AddressEvent {
  final Address address;

  const AddAddress(this.address);

  @override
  List<Object?> get props => [address];
}

class UpdateAddress extends AddressEvent {
  final int id;
  final Address address;

  const UpdateAddress(this.id, this.address);

  @override
  List<Object?> get props => [id, address];
}

class DeleteAddress extends AddressEvent {
  final int id;
  final String userId;

  const DeleteAddress(this.id, this.userId);

  @override
  List<Object?> get props => [id, userId];
}

class SetDefaultAddress extends AddressEvent {
  final int id;
  final String userId;

  const SetDefaultAddress(this.id, this.userId);

  @override
  List<Object?> get props => [id, userId];
}

abstract class AddressState extends Equatable {
  const AddressState();

  @override
  List<Object?> get props => [];
}

class AddressInitial extends AddressState {}

class AddressLoading extends AddressState {}

class AddressLoaded extends AddressState {
  final List<Address> addresses;

  const AddressLoaded(this.addresses);

  @override
  List<Object?> get props => [addresses];
}

class AddressOperationSuccess extends AddressState {
  final String message;

  const AddressOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class AddressError extends AddressState {
  final String message;

  const AddressError(this.message);

  @override
  List<Object?> get props => [message];
}

class AddressBloc extends Bloc<AddressEvent, AddressState> {
  final ProductDatabaseService _db;

  AddressBloc(this._db) : super(AddressInitial()) {
    on<LoadAddresses>(_onLoadAddresses);
    on<AddAddress>(_onAddAddress);
    on<UpdateAddress>(_onUpdateAddress);
    on<DeleteAddress>(_onDeleteAddress);
    on<SetDefaultAddress>(_onSetDefaultAddress);
  }

  Future<void> _onLoadAddresses(
      LoadAddresses event, Emitter<AddressState> emit) async {
    emit(AddressLoading());
    try {
      final addresses = await _db.getUserAddresses(event.userId);
      emit(AddressLoaded(addresses));
    } catch (e) {
      emit(AddressError('加载地址失败: $e'));
    }
  }

  Future<void> _onAddAddress(
      AddAddress event, Emitter<AddressState> emit) async {
    try {
      await _db.insertAddress(event.address);
      emit(const AddressOperationSuccess('添加地址成功'));
      add(LoadAddresses(event.address.userId));
    } catch (e) {
      emit(AddressError('添加地址失败: $e'));
    }
  }

  Future<void> _onUpdateAddress(
      UpdateAddress event, Emitter<AddressState> emit) async {
    try {
      await _db.updateAddress(event.id, event.address);
      emit(const AddressOperationSuccess('更新地址成功'));
      add(LoadAddresses(event.address.userId));
    } catch (e) {
      emit(AddressError('更新地址失败: $e'));
    }
  }

  Future<void> _onDeleteAddress(
      DeleteAddress event, Emitter<AddressState> emit) async {
    try {
      await _db.deleteAddress(event.id);
      emit(const AddressOperationSuccess('删除地址成功'));
      add(LoadAddresses(event.userId));
    } catch (e) {
      emit(AddressError('删除地址失败: $e'));
    }
  }

  Future<void> _onSetDefaultAddress(
      SetDefaultAddress event, Emitter<AddressState> emit) async {
    try {
      await _db.setDefaultAddress(event.id, event.userId);
      emit(const AddressOperationSuccess('设置默认地址成功'));
      add(LoadAddresses(event.userId));
    } catch (e) {
      emit(AddressError('设置默认地址失败: $e'));
    }
  }
}

/// ==========================================
/// 会员等级 BLoC
/// ==========================================

abstract class MemberLevelEvent extends Equatable {
  const MemberLevelEvent();

  @override
  List<Object?> get props => [];
}

class LoadMemberLevels extends MemberLevelEvent {}

class AddMemberLevel extends MemberLevelEvent {
  final MemberLevel level;

  const AddMemberLevel(this.level);

  @override
  List<Object?> get props => [level];
}

class UpdateMemberLevel extends MemberLevelEvent {
  final int id;
  final MemberLevel level;

  const UpdateMemberLevel(this.id, this.level);

  @override
  List<Object?> get props => [id, level];
}

class DeleteMemberLevel extends MemberLevelEvent {
  final int id;

  const DeleteMemberLevel(this.id);

  @override
  List<Object?> get props => [id];
}

class GetMemberLevelByPoints extends MemberLevelEvent {
  final int points;

  const GetMemberLevelByPoints(this.points);

  @override
  List<Object?> get props => [points];
}

abstract class MemberLevelState extends Equatable {
  const MemberLevelState();

  @override
  List<Object?> get props => [];
}

class MemberLevelInitial extends MemberLevelState {}

class MemberLevelLoading extends MemberLevelState {}

class MemberLevelLoaded extends MemberLevelState {
  final List<MemberLevel> levels;
  final MemberLevel? currentLevel;

  const MemberLevelLoaded(this.levels, {this.currentLevel});

  @override
  List<Object?> get props => [levels, currentLevel];
}

class MemberLevelOperationSuccess extends MemberLevelState {
  final String message;

  const MemberLevelOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class MemberLevelError extends MemberLevelState {
  final String message;

  const MemberLevelError(this.message);

  @override
  List<Object?> get props => [message];
}

class MemberBloc extends Bloc<MemberLevelEvent, MemberLevelState> {
  final ProductDatabaseService _db;

  MemberBloc(this._db) : super(MemberLevelInitial()) {
    on<LoadMemberLevels>(_onLoadMemberLevels);
    on<AddMemberLevel>(_onAddMemberLevel);
    on<UpdateMemberLevel>(_onUpdateMemberLevel);
    on<DeleteMemberLevel>(_onDeleteMemberLevel);
    on<GetMemberLevelByPoints>(_onGetMemberLevelByPoints);
  }

  Future<void> _onLoadMemberLevels(
      LoadMemberLevels event, Emitter<MemberLevelState> emit) async {
    emit(MemberLevelLoading());
    try {
      final levels = await _db.getAllMemberLevels();
      emit(MemberLevelLoaded(levels));
    } catch (e) {
      emit(MemberLevelError('加载会员等级失败: $e'));
    }
  }

  Future<void> _onAddMemberLevel(
      AddMemberLevel event, Emitter<MemberLevelState> emit) async {
    try {
      await _db.insertMemberLevel(event.level);
      emit(const MemberLevelOperationSuccess('添加会员等级成功'));
      add(LoadMemberLevels());
    } catch (e) {
      emit(MemberLevelError('添加会员等级失败: $e'));
    }
  }

  Future<void> _onUpdateMemberLevel(
      UpdateMemberLevel event, Emitter<MemberLevelState> emit) async {
    try {
      await _db.updateMemberLevel(event.id, event.level);
      emit(const MemberLevelOperationSuccess('更新会员等级成功'));
      add(LoadMemberLevels());
    } catch (e) {
      emit(MemberLevelError('更新会员等级失败: $e'));
    }
  }

  Future<void> _onDeleteMemberLevel(
      DeleteMemberLevel event, Emitter<MemberLevelState> emit) async {
    try {
      await _db.deleteMemberLevel(event.id);
      emit(const MemberLevelOperationSuccess('删除会员等级成功'));
      add(LoadMemberLevels());
    } catch (e) {
      emit(MemberLevelError('删除会员等级失败: $e'));
    }
  }

  Future<void> _onGetMemberLevelByPoints(
      GetMemberLevelByPoints event, Emitter<MemberLevelState> emit) async {
    emit(MemberLevelLoading());
    try {
      final levels = await _db.getAllMemberLevels();
      final currentLevel = await _db.getMemberLevelByPoints(event.points);
      emit(MemberLevelLoaded(levels, currentLevel: currentLevel));
    } catch (e) {
      emit(MemberLevelError('获取会员等级失败: $e'));
    }
  }
}

/// ==========================================
/// 优惠券 BLoC
/// ==========================================

abstract class CouponEvent extends Equatable {
  const CouponEvent();

  @override
  List<Object?> get props => [];
}

class LoadCoupons extends CouponEvent {
  final bool? isActive;

  const LoadCoupons({this.isActive});

  @override
  List<Object?> get props => [isActive];
}

class LoadUserCoupons extends CouponEvent {
  final String userId;
  final String? status;

  const LoadUserCoupons(this.userId, {this.status});

  @override
  List<Object?> get props => [userId, status];
}

class AddCoupon extends CouponEvent {
  final Coupon coupon;

  const AddCoupon(this.coupon);

  @override
  List<Object?> get props => [coupon];
}

class UpdateCoupon extends CouponEvent {
  final int id;
  final Coupon coupon;

  const UpdateCoupon(this.id, this.coupon);

  @override
  List<Object?> get props => [id, coupon];
}

class DeleteCoupon extends CouponEvent {
  final int id;

  const DeleteCoupon(this.id);

  @override
  List<Object?> get props => [id];
}

class ClaimCoupon extends CouponEvent {
  final String userId;
  final int couponId;

  const ClaimCoupon(this.userId, this.couponId);

  @override
  List<Object?> get props => [userId, couponId];
}

class UseCoupon extends CouponEvent {
  final int id;
  final String orderId;

  const UseCoupon(this.id, this.orderId);

  @override
  List<Object?> get props => [id, orderId];
}

abstract class CouponState extends Equatable {
  const CouponState();

  @override
  List<Object?> get props => [];
}

class CouponInitial extends CouponState {}

class CouponLoading extends CouponState {}

class CouponLoaded extends CouponState {
  final List<Coupon> coupons;
  final List<Map<String, dynamic>>? userCoupons;

  const CouponLoaded(this.coupons, {this.userCoupons});

  @override
  List<Object?> get props => [coupons, userCoupons];
}

class CouponOperationSuccess extends CouponState {
  final String message;

  const CouponOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class CouponError extends CouponState {
  final String message;

  const CouponError(this.message);

  @override
  List<Object?> get props => [message];
}

class CouponBloc extends Bloc<CouponEvent, CouponState> {
  final ProductDatabaseService _db;

  CouponBloc(this._db) : super(CouponInitial()) {
    on<LoadCoupons>(_onLoadCoupons);
    on<LoadUserCoupons>(_onLoadUserCoupons);
    on<AddCoupon>(_onAddCoupon);
    on<UpdateCoupon>(_onUpdateCoupon);
    on<DeleteCoupon>(_onDeleteCoupon);
    on<ClaimCoupon>(_onClaimCoupon);
    on<UseCoupon>(_onUseCoupon);
  }

  Future<void> _onLoadCoupons(
      LoadCoupons event, Emitter<CouponState> emit) async {
    emit(CouponLoading());
    try {
      final coupons = await _db.getAllCoupons(isActive: event.isActive);
      emit(CouponLoaded(coupons));
    } catch (e) {
      emit(CouponError('加载优惠券失败: $e'));
    }
  }

  Future<void> _onLoadUserCoupons(
      LoadUserCoupons event, Emitter<CouponState> emit) async {
    emit(CouponLoading());
    try {
      final coupons = await _db.getAllCoupons(isActive: true);
      final userCoupons = event.status != null
          ? await _db.getUserCoupons(event.userId, status: event.status)
          : await _db.getUserCoupons(event.userId);
      emit(CouponLoaded(coupons, userCoupons: userCoupons));
    } catch (e) {
      emit(CouponError('加载用户优惠券失败: $e'));
    }
  }

  Future<void> _onAddCoupon(
      AddCoupon event, Emitter<CouponState> emit) async {
    try {
      await _db.insertCoupon(event.coupon);
      emit(const CouponOperationSuccess('添加优惠券成功'));
      add(const LoadCoupons());
    } catch (e) {
      emit(CouponError('添加优惠券失败: $e'));
    }
  }

  Future<void> _onUpdateCoupon(
      UpdateCoupon event, Emitter<CouponState> emit) async {
    try {
      await _db.updateCoupon(event.id, event.coupon);
      emit(const CouponOperationSuccess('更新优惠券成功'));
      add(const LoadCoupons());
    } catch (e) {
      emit(CouponError('更新优惠券失败: $e'));
    }
  }

  Future<void> _onDeleteCoupon(
      DeleteCoupon event, Emitter<CouponState> emit) async {
    try {
      await _db.deleteCoupon(event.id);
      emit(const CouponOperationSuccess('删除优惠券成功'));
      add(const LoadCoupons());
    } catch (e) {
      emit(CouponError('删除优惠券失败: $e'));
    }
  }

  Future<void> _onClaimCoupon(
      ClaimCoupon event, Emitter<CouponState> emit) async {
    try {
      final coupon = await _db.getCouponById(event.couponId);
      if (coupon == null) {
        emit(const CouponError('优惠券不存在'));
        return;
      }
      if (coupon.usedCount >= coupon.totalCount) {
        emit(const CouponError('优惠券已领完'));
        return;
      }

      final now = DateTime.now();
      final expiresAt = coupon.validDays != null
          ? now.add(Duration(days: coupon.validDays!))
          : coupon.endTime;

      final userCoupon = UserCoupon(
        userId: event.userId,
        couponId: event.couponId,
        createdAt: now,
        expiresAt: expiresAt,
      );

      await _db.insertUserCoupon(userCoupon);
      await _db.incrementCouponUsedCount(event.couponId);
      emit(const CouponOperationSuccess('领取优惠券成功'));
    } catch (e) {
      emit(CouponError('领取优惠券失败: $e'));
    }
  }

  Future<void> _onUseCoupon(
      UseCoupon event, Emitter<CouponState> emit) async {
    try {
      await _db.useUserCoupon(event.id, event.orderId);
      emit(const CouponOperationSuccess('使用优惠券成功'));
    } catch (e) {
      emit(CouponError('使用优惠券失败: $e'));
    }
  }
}

/// ==========================================
/// 购物卡 BLoC
/// ==========================================

abstract class ShoppingCardEvent extends Equatable {
  const ShoppingCardEvent();

  @override
  List<Object?> get props => [];
}

class LoadShoppingCards extends ShoppingCardEvent {
  final String? status;
  final String? userId;

  const LoadShoppingCards({this.status, this.userId});

  @override
  List<Object?> get props => [status, userId];
}

class AddShoppingCard extends ShoppingCardEvent {
  final ShoppingCard card;

  const AddShoppingCard(this.card);

  @override
  List<Object?> get props => [card];
}

class ActivateShoppingCard extends ShoppingCardEvent {
  final int id;
  final String userId;

  const ActivateShoppingCard(this.id, this.userId);

  @override
  List<Object?> get props => [id, userId];
}

class UseShoppingCard extends ShoppingCardEvent {
  final int id;
  final int amount;
  final String? orderId;
  final String description;

  const UseShoppingCard(this.id, this.amount, this.orderId, this.description);

  @override
  List<Object?> get props => [id, amount, orderId, description];
}

class DeleteShoppingCard extends ShoppingCardEvent {
  final int id;

  const DeleteShoppingCard(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadShoppingCardTransactions extends ShoppingCardEvent {
  final int cardId;

  const LoadShoppingCardTransactions(this.cardId);

  @override
  List<Object?> get props => [cardId];
}

abstract class ShoppingCardState extends Equatable {
  const ShoppingCardState();

  @override
  List<Object?> get props => [];
}

class ShoppingCardInitial extends ShoppingCardState {}

class ShoppingCardLoading extends ShoppingCardState {}

class ShoppingCardLoaded extends ShoppingCardState {
  final List<ShoppingCard> cards;
  final List<ShoppingCardTransaction>? transactions;

  const ShoppingCardLoaded(this.cards, {this.transactions});

  @override
  List<Object?> get props => [cards, transactions];
}

class ShoppingCardOperationSuccess extends ShoppingCardState {
  final String message;

  const ShoppingCardOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ShoppingCardError extends ShoppingCardState {
  final String message;

  const ShoppingCardError(this.message);

  @override
  List<Object?> get props => [message];
}

class ShoppingCardBloc extends Bloc<ShoppingCardEvent, ShoppingCardState> {
  final ProductDatabaseService _db;

  ShoppingCardBloc(this._db) : super(ShoppingCardInitial()) {
    on<LoadShoppingCards>(_onLoadShoppingCards);
    on<AddShoppingCard>(_onAddShoppingCard);
    on<ActivateShoppingCard>(_onActivateShoppingCard);
    on<UseShoppingCard>(_onUseShoppingCard);
    on<DeleteShoppingCard>(_onDeleteShoppingCard);
    on<LoadShoppingCardTransactions>(_onLoadTransactions);
  }

  Future<void> _onLoadShoppingCards(
      LoadShoppingCards event, Emitter<ShoppingCardState> emit) async {
    emit(ShoppingCardLoading());
    try {
      final cards = await _db.getAllShoppingCards(
        status: event.status,
        userId: event.userId,
      );
      emit(ShoppingCardLoaded(cards));
    } catch (e) {
      emit(ShoppingCardError('加载购物卡失败: $e'));
    }
  }

  Future<void> _onAddShoppingCard(
      AddShoppingCard event, Emitter<ShoppingCardState> emit) async {
    try {
      await _db.insertShoppingCard(event.card);
      emit(const ShoppingCardOperationSuccess('添加购物卡成功'));
      add(const LoadShoppingCards());
    } catch (e) {
      emit(ShoppingCardError('添加购物卡失败: $e'));
    }
  }

  Future<void> _onActivateShoppingCard(
      ActivateShoppingCard event, Emitter<ShoppingCardState> emit) async {
    try {
      await _db.activateShoppingCard(event.id, event.userId);
      emit(const ShoppingCardOperationSuccess('激活购物卡成功'));
      add(LoadShoppingCards(userId: event.userId));
    } catch (e) {
      emit(ShoppingCardError('激活购物卡失败: $e'));
    }
  }

  Future<void> _onUseShoppingCard(
      UseShoppingCard event, Emitter<ShoppingCardState> emit) async {
    try {
      final card = await _db.getShoppingCardById(event.id);
      if (card == null) {
        emit(const ShoppingCardError('购物卡不存在'));
        return;
      }
      if (card.balance < event.amount) {
        emit(const ShoppingCardError('余额不足'));
        return;
      }

      final newBalance = card.balance - event.amount;
      await _db.updateShoppingCardBalance(event.id, newBalance);

      final transaction = ShoppingCardTransaction(
        shoppingCardId: event.id,
        orderId: event.orderId,
        amount: -event.amount,
        type: 'consume',
        balanceBefore: card.balance,
        balanceAfter: newBalance,
        description: event.description,
        createdAt: DateTime.now(),
      );
      await _db.insertShoppingCardTransaction(transaction);

      emit(const ShoppingCardOperationSuccess('使用购物卡成功'));
    } catch (e) {
      emit(ShoppingCardError('使用购物卡失败: $e'));
    }
  }

  Future<void> _onDeleteShoppingCard(
      DeleteShoppingCard event, Emitter<ShoppingCardState> emit) async {
    try {
      await _db.deleteShoppingCard(event.id);
      emit(const ShoppingCardOperationSuccess('删除购物卡成功'));
      add(const LoadShoppingCards());
    } catch (e) {
      emit(ShoppingCardError('删除购物卡失败: $e'));
    }
  }

  Future<void> _onLoadTransactions(
      LoadShoppingCardTransactions event, Emitter<ShoppingCardState> emit) async {
    emit(ShoppingCardLoading());
    try {
      final cards = await _db.getAllShoppingCards();
      final transactions = await _db.getShoppingCardTransactions(event.cardId);
      emit(ShoppingCardLoaded(cards, transactions: transactions));
    } catch (e) {
      emit(ShoppingCardError('加载交易记录失败: $e'));
    }
  }
}

/// ==========================================
/// 红包 BLoC
/// ==========================================

abstract class RedPacketEvent extends Equatable {
  const RedPacketEvent();

  @override
  List<Object?> get props => [];
}

class LoadRedPackets extends RedPacketEvent {
  final bool? isActive;

  const LoadRedPackets({this.isActive});

  @override
  List<Object?> get props => [isActive];
}

class LoadUserRedPackets extends RedPacketEvent {
  final String userId;

  const LoadUserRedPackets(this.userId);

  @override
  List<Object?> get props => [userId];
}

class AddRedPacket extends RedPacketEvent {
  final RedPacket redPacket;

  const AddRedPacket(this.redPacket);

  @override
  List<Object?> get props => [redPacket];
}

class ClaimRedPacket extends RedPacketEvent {
  final int redPacketId;
  final String userId;

  const ClaimRedPacket(this.redPacketId, this.userId);

  @override
  List<Object?> get props => [redPacketId, userId];
}

class DeleteRedPacket extends RedPacketEvent {
  final int id;

  const DeleteRedPacket(this.id);

  @override
  List<Object?> get props => [id];
}

abstract class RedPacketState extends Equatable {
  const RedPacketState();

  @override
  List<Object?> get props => [];
}

class RedPacketInitial extends RedPacketState {}

class RedPacketLoading extends RedPacketState {}

class RedPacketLoaded extends RedPacketState {
  final List<RedPacket> redPackets;
  final List<RedPacketClaim>? userClaims;

  const RedPacketLoaded(this.redPackets, {this.userClaims});

  @override
  List<Object?> get props => [redPackets, userClaims];
}

class RedPacketOperationSuccess extends RedPacketState {
  final String message;

  const RedPacketOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class RedPacketError extends RedPacketState {
  final String message;

  const RedPacketError(this.message);

  @override
  List<Object?> get props => [message];
}

class RedPacketBloc extends Bloc<RedPacketEvent, RedPacketState> {
  final ProductDatabaseService _db;

  RedPacketBloc(this._db) : super(RedPacketInitial()) {
    on<LoadRedPackets>(_onLoadRedPackets);
    on<LoadUserRedPackets>(_onLoadUserRedPackets);
    on<AddRedPacket>(_onAddRedPacket);
    on<ClaimRedPacket>(_onClaimRedPacket);
    on<DeleteRedPacket>(_onDeleteRedPacket);
  }

  Future<void> _onLoadRedPackets(
      LoadRedPackets event, Emitter<RedPacketState> emit) async {
    emit(RedPacketLoading());
    try {
      final redPackets = await _db.getAllRedPackets(isActive: event.isActive);
      emit(RedPacketLoaded(redPackets));
    } catch (e) {
      emit(RedPacketError('加载红包失败: $e'));
    }
  }

  Future<void> _onLoadUserRedPackets(
      LoadUserRedPackets event, Emitter<RedPacketState> emit) async {
    emit(RedPacketLoading());
    try {
      final redPackets = await _db.getAllRedPackets(isActive: true);
      final userClaims = await _db.getUserRedPacketClaims(event.userId);
      emit(RedPacketLoaded(redPackets, userClaims: userClaims));
    } catch (e) {
      emit(RedPacketError('加载用户红包失败: $e'));
    }
  }

  Future<void> _onAddRedPacket(
      AddRedPacket event, Emitter<RedPacketState> emit) async {
    try {
      await _db.insertRedPacket(event.redPacket);
      emit(const RedPacketOperationSuccess('添加红包成功'));
      add(const LoadRedPackets());
    } catch (e) {
      emit(RedPacketError('添加红包失败: $e'));
    }
  }

  Future<void> _onClaimRedPacket(
      ClaimRedPacket event, Emitter<RedPacketState> emit) async {
    try {
      final redPacket = await _db.getRedPacketById(event.redPacketId);
      if (redPacket == null) {
        emit(const RedPacketError('红包不存在'));
        return;
      }
      if (redPacket.receivedCount >= redPacket.totalCount) {
        emit(const RedPacketError('红包已领完'));
        return;
      }

      final now = DateTime.now();
      if (redPacket.startTime != null && now.isBefore(redPacket.startTime!)) {
        emit(const RedPacketError('红包还未开始'));
        return;
      }
      if (redPacket.endTime != null && now.isAfter(redPacket.endTime!)) {
        emit(const RedPacketError('红包已过期'));
        return;
      }

      int amount;
      if (redPacket.type == 'fixed') {
        amount = (redPacket.totalAmount / redPacket.totalCount).round();
      } else {
        final remaining = redPacket.totalAmount -
            redPacket.receivedCount * (redPacket.maxAmount ?? 100);
        final left = redPacket.totalCount - redPacket.receivedCount;
        amount = redPacket.minAmount ?? 1;
        if (left > 1) {
          final max = remaining - (left - 1) * (redPacket.minAmount ?? 1);
          amount = DateTime.now().millisecond % (max - amount + 1) + amount;
        }
      }

      final claim = RedPacketClaim(
        redPacketId: event.redPacketId,
        userId: event.userId,
        amount: amount,
        claimedAt: now,
      );

      await _db.insertRedPacketClaim(claim);
      await _db.incrementRedPacketReceivedCount(event.redPacketId);

      emit(RedPacketOperationSuccess('恭喜！抢到了 $amount 积分'));
    } catch (e) {
      emit(RedPacketError('领取红包失败: $e'));
    }
  }

  Future<void> _onDeleteRedPacket(
      DeleteRedPacket event, Emitter<RedPacketState> emit) async {
    try {
      await _db.deleteRedPacket(event.id);
      emit(const RedPacketOperationSuccess('删除红包成功'));
      add(const LoadRedPackets());
    } catch (e) {
      emit(RedPacketError('删除红包失败: $e'));
    }
  }
}

/// ==========================================
/// 物流管理 BLoC
/// ==========================================

abstract class LogisticsEvent extends Equatable {
  const LogisticsEvent();

  @override
  List<Object?> get props => [];
}

class LoadLogisticsCompanies extends LogisticsEvent {
  final bool? isActive;

  const LoadLogisticsCompanies({this.isActive});

  @override
  List<Object?> get props => [isActive];
}

class AddLogisticsCompany extends LogisticsEvent {
  final LogisticsCompany company;

  const AddLogisticsCompany(this.company);

  @override
  List<Object?> get props => [company];
}

class UpdateLogisticsCompany extends LogisticsEvent {
  final int id;
  final LogisticsCompany company;

  const UpdateLogisticsCompany(this.id, this.company);

  @override
  List<Object?> get props => [id, company];
}

class DeleteLogisticsCompany extends LogisticsEvent {
  final int id;

  const DeleteLogisticsCompany(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadLogisticsTracks extends LogisticsEvent {
  final String orderId;

  const LoadLogisticsTracks(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class AddLogisticsTrack extends LogisticsEvent {
  final LogisticsTrack track;

  const AddLogisticsTrack(this.track);

  @override
  List<Object?> get props => [track];
}

class UpdateLogisticsTrack extends LogisticsEvent {
  final int id;
  final String status;
  final String description;
  final String? location;

  const UpdateLogisticsTrack(this.id, this.status, this.description, {this.location});

  @override
  List<Object?> get props => [id, status, description, location];
}

abstract class LogisticsState extends Equatable {
  const LogisticsState();

  @override
  List<Object?> get props => [];
}

class LogisticsInitial extends LogisticsState {}

class LogisticsLoading extends LogisticsState {}

class LogisticsLoaded extends LogisticsState {
  final List<LogisticsCompany> companies;
  final List<LogisticsTrack>? tracks;

  const LogisticsLoaded(this.companies, {this.tracks});

  @override
  List<Object?> get props => [companies, tracks];
}

class LogisticsOperationSuccess extends LogisticsState {
  final String message;

  const LogisticsOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class LogisticsError extends LogisticsState {
  final String message;

  const LogisticsError(this.message);

  @override
  List<Object?> get props => [message];
}

class LogisticsBloc extends Bloc<LogisticsEvent, LogisticsState> {
  final ProductDatabaseService _db;

  LogisticsBloc(this._db) : super(LogisticsInitial()) {
    on<LoadLogisticsCompanies>(_onLoadLogisticsCompanies);
    on<AddLogisticsCompany>(_onAddLogisticsCompany);
    on<UpdateLogisticsCompany>(_onUpdateLogisticsCompany);
    on<DeleteLogisticsCompany>(_onDeleteLogisticsCompany);
    on<LoadLogisticsTracks>(_onLoadLogisticsTracks);
    on<AddLogisticsTrack>(_onAddLogisticsTrack);
    on<UpdateLogisticsTrack>(_onUpdateLogisticsTrack);
  }

  Future<void> _onLoadLogisticsCompanies(
      LoadLogisticsCompanies event, Emitter<LogisticsState> emit) async {
    emit(LogisticsLoading());
    try {
      final companies = await _db.getAllLogisticsCompanies(isActive: event.isActive);
      emit(LogisticsLoaded(companies));
    } catch (e) {
      emit(LogisticsError('加载物流公司失败: $e'));
    }
  }

  Future<void> _onAddLogisticsCompany(
      AddLogisticsCompany event, Emitter<LogisticsState> emit) async {
    try {
      await _db.insertLogisticsCompany(event.company);
      emit(const LogisticsOperationSuccess('添加物流公司成功'));
      add(const LoadLogisticsCompanies());
    } catch (e) {
      emit(LogisticsError('添加物流公司失败: $e'));
    }
  }

  Future<void> _onUpdateLogisticsCompany(
      UpdateLogisticsCompany event, Emitter<LogisticsState> emit) async {
    try {
      await _db.updateLogisticsCompany(event.id, event.company);
      emit(const LogisticsOperationSuccess('更新物流公司成功'));
      add(const LoadLogisticsCompanies());
    } catch (e) {
      emit(LogisticsError('更新物流公司失败: $e'));
    }
  }

  Future<void> _onDeleteLogisticsCompany(
      DeleteLogisticsCompany event, Emitter<LogisticsState> emit) async {
    try {
      await _db.deleteLogisticsCompany(event.id);
      emit(const LogisticsOperationSuccess('删除物流公司成功'));
      add(const LoadLogisticsCompanies());
    } catch (e) {
      emit(LogisticsError('删除物流公司失败: $e'));
    }
  }

  Future<void> _onLoadLogisticsTracks(
      LoadLogisticsTracks event, Emitter<LogisticsState> emit) async {
    emit(LogisticsLoading());
    try {
      final companies = await _db.getAllLogisticsCompanies(isActive: true);
      final tracks = await _db.getLogisticsTracksByOrderId(event.orderId);
      emit(LogisticsLoaded(companies, tracks: tracks));
    } catch (e) {
      emit(LogisticsError('加载物流跟踪失败: $e'));
    }
  }

  Future<void> _onAddLogisticsTrack(
      AddLogisticsTrack event, Emitter<LogisticsState> emit) async {
    try {
      await _db.insertLogisticsTrack(event.track);
      emit(const LogisticsOperationSuccess('添加物流跟踪成功'));
      add(LoadLogisticsTracks(event.track.orderId));
    } catch (e) {
      emit(LogisticsError('添加物流跟踪失败: $e'));
    }
  }

  Future<void> _onUpdateLogisticsTrack(
      UpdateLogisticsTrack event, Emitter<LogisticsState> emit) async {
    try {
      await _db.updateLogisticsTrackStatus(
        event.id,
        event.status,
        event.description,
        location: event.location,
      );
      emit(const LogisticsOperationSuccess('更新物流状态成功'));
    } catch (e) {
      emit(LogisticsError('更新物流状态失败: $e'));
    }
  }
}

/// ==========================================
/// 商家管理 BLoC
/// ==========================================

abstract class MerchantEvent extends Equatable {
  const MerchantEvent();

  @override
  List<Object?> get props => [];
}

class LoadMerchants extends MerchantEvent {
  final String? status;

  const LoadMerchants({this.status});

  @override
  List<Object?> get props => [status];
}

class LoadMerchantByUserId extends MerchantEvent {
  final String userId;

  const LoadMerchantByUserId(this.userId);

  @override
  List<Object?> get props => [userId];
}

class AddMerchant extends MerchantEvent {
  final Merchant merchant;

  const AddMerchant(this.merchant);

  @override
  List<Object?> get props => [merchant];
}

class UpdateMerchant extends MerchantEvent {
  final int id;
  final Merchant merchant;

  const UpdateMerchant(this.id, this.merchant);

  @override
  List<Object?> get props => [id, merchant];
}

class ApproveMerchant extends MerchantEvent {
  final int id;

  const ApproveMerchant(this.id);

  @override
  List<Object?> get props => [id];
}

class RejectMerchant extends MerchantEvent {
  final int id;

  const RejectMerchant(this.id);

  @override
  List<Object?> get props => [id];
}

class SuspendMerchant extends MerchantEvent {
  final int id;

  const SuspendMerchant(this.id);

  @override
  List<Object?> get props => [id];
}

class DeleteMerchant extends MerchantEvent {
  final int id;

  const DeleteMerchant(this.id);

  @override
  List<Object?> get props => [id];
}

abstract class MerchantState extends Equatable {
  const MerchantState();

  @override
  List<Object?> get props => [];
}

class MerchantInitial extends MerchantState {}

class MerchantLoading extends MerchantState {}

class MerchantLoaded extends MerchantState {
  final List<Merchant> merchants;
  final Merchant? currentMerchant;

  const MerchantLoaded(this.merchants, {this.currentMerchant});

  @override
  List<Object?> get props => [merchants, currentMerchant];
}

class MerchantOperationSuccess extends MerchantState {
  final String message;

  const MerchantOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class MerchantError extends MerchantState {
  final String message;

  const MerchantError(this.message);

  @override
  List<Object?> get props => [message];
}

class MerchantBloc extends Bloc<MerchantEvent, MerchantState> {
  final ProductDatabaseService _db;

  MerchantBloc(this._db) : super(MerchantInitial()) {
    on<LoadMerchants>(_onLoadMerchants);
    on<LoadMerchantByUserId>(_onLoadMerchantByUserId);
    on<AddMerchant>(_onAddMerchant);
    on<UpdateMerchant>(_onUpdateMerchant);
    on<ApproveMerchant>(_onApproveMerchant);
    on<RejectMerchant>(_onRejectMerchant);
    on<SuspendMerchant>(_onSuspendMerchant);
    on<DeleteMerchant>(_onDeleteMerchant);
  }

  Future<void> _onLoadMerchants(
      LoadMerchants event, Emitter<MerchantState> emit) async {
    emit(MerchantLoading());
    try {
      final merchants = await _db.getAllMerchants(status: event.status);
      emit(MerchantLoaded(merchants));
    } catch (e) {
      emit(MerchantError('加载商家失败: $e'));
    }
  }

  Future<void> _onLoadMerchantByUserId(
      LoadMerchantByUserId event, Emitter<MerchantState> emit) async {
    emit(MerchantLoading());
    try {
      final merchants = await _db.getAllMerchants();
      final merchant = await _db.getMerchantByUserId(event.userId);
      emit(MerchantLoaded(merchants, currentMerchant: merchant));
    } catch (e) {
      emit(MerchantError('加载商家信息失败: $e'));
    }
  }

  Future<void> _onAddMerchant(
      AddMerchant event, Emitter<MerchantState> emit) async {
    try {
      await _db.insertMerchant(event.merchant);
      emit(const MerchantOperationSuccess('提交商家申请成功'));
      add(LoadMerchants());
    } catch (e) {
      emit(MerchantError('提交商家申请失败: $e'));
    }
  }

  Future<void> _onUpdateMerchant(
      UpdateMerchant event, Emitter<MerchantState> emit) async {
    try {
      await _db.updateMerchant(event.id, event.merchant);
      emit(const MerchantOperationSuccess('更新商家信息成功'));
      add(LoadMerchants());
    } catch (e) {
      emit(MerchantError('更新商家信息失败: $e'));
    }
  }

  Future<void> _onApproveMerchant(
      ApproveMerchant event, Emitter<MerchantState> emit) async {
    try {
      await _db.updateMerchantStatus(event.id, 'active');
      emit(const MerchantOperationSuccess('审核通过'));
      add(LoadMerchants());
    } catch (e) {
      emit(MerchantError('审核操作失败: $e'));
    }
  }

  Future<void> _onRejectMerchant(
      RejectMerchant event, Emitter<MerchantState> emit) async {
    try {
      await _db.updateMerchantStatus(event.id, 'rejected');
      emit(const MerchantOperationSuccess('审核拒绝'));
      add(LoadMerchants());
    } catch (e) {
      emit(MerchantError('审核操作失败: $e'));
    }
  }

  Future<void> _onSuspendMerchant(
      SuspendMerchant event, Emitter<MerchantState> emit) async {
    try {
      await _db.updateMerchantStatus(event.id, 'suspended');
      emit(const MerchantOperationSuccess('已暂停营业'));
      add(LoadMerchants());
    } catch (e) {
      emit(MerchantError('操作失败: $e'));
    }
  }

  Future<void> _onDeleteMerchant(
      DeleteMerchant event, Emitter<MerchantState> emit) async {
    try {
      await _db.deleteMerchant(event.id);
      emit(const MerchantOperationSuccess('删除商家成功'));
      add(LoadMerchants());
    } catch (e) {
      emit(MerchantError('删除商家失败: $e'));
    }
  }
}
