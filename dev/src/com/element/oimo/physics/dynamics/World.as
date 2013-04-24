/* Copyright (c) 2012 EL-EMENT saharan
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this
 * software and associated documentation  * files (the "Software"), to deal in the Software
 * without restriction, including without limitation the rights to use, copy,  * modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to
 * whom the Software is furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
 * PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
 * ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
package com.element.oimo.physics.dynamics {
	import com.element.oimo.math.Quat;
	import com.element.oimo.physics.collision.broadphase.BroadPhase;
	import com.element.oimo.physics.collision.broadphase.BruteForceBroadPhase;
	import com.element.oimo.physics.collision.broadphase.DynamicBVTreeBroadPhase;
	import com.element.oimo.physics.collision.broadphase.Pair;
	import com.element.oimo.physics.collision.broadphase.SweepAndPruneBroadPhase;
	import com.element.oimo.physics.collision.broadphase.SweepAndPruneBroadPhase_;
	import com.element.oimo.physics.collision.narrow.BoxBoxCollisionDetector;
	import com.element.oimo.physics.collision.narrow.BoxCylinderCollisionDetector;
	import com.element.oimo.physics.collision.narrow.CollisionDetector;
	import com.element.oimo.physics.collision.narrow.CylinderCylinderCollisionDetector;
	import com.element.oimo.physics.collision.narrow.SphereBoxCollisionDetector;
	import com.element.oimo.physics.collision.narrow.SphereCylinderCollisionDetector;
	import com.element.oimo.physics.collision.narrow.SphereSphereCollisionDetector;
	import com.element.oimo.physics.collision.shape.Shape;
	import com.element.oimo.math.Vec3;
	import com.element.oimo.physics.constraint.Constraint;
	import com.element.oimo.physics.constraint.contact.Contact;
	import com.element.oimo.physics.constraint.contact.ContactConstraint;
	import com.element.oimo.physics.constraint.contact.ContactLink;
	import com.element.oimo.physics.constraint.joint.Joint;
	import com.element.oimo.physics.constraint.joint.JointLink;
	import com.element.oimo.physics.util.Performance;
	import flash.utils.getTimer;
	/**
	 * 物理演算ワールドのクラスです。
	 * 全ての物理演算オブジェクトはワールドに追加する必要があります。
	 * @author saharan
	 */
	public class World {
		/**
		 * 追加できる剛体の最大数です。
		 */
		public static const MAX_BODIES:uint = 16384;
		
		/**
		 * 追加できる形状の最大数です。
		 */
		public static const MAX_SHAPES:uint = 65536;
		
		/**
		 * 検出できる接触点の最大数です。
		 */
		public static const MAX_CONTACTS:uint = 65536;
		
		/**
		 * 追加できるジョイントの最大数です。
		 */
		public static const MAX_JOINTS:uint = 16384;
		
		private static const MAX_CONSTRAINTS:uint = MAX_CONTACTS + MAX_JOINTS;
		
		/**
		 * 追加されている剛体のリンクリストです。
		 * <strong>この変数は外部から変更しないでください。</strong>
		 */
		public var rigidBodies:RigidBody;
		
		/**
		 * 追加されている剛体の数です。
		 * <strong>この変数は外部から変更しないでください。</strong>
		 */
		public var numRigidBodies:uint;
		
		/**
		 * 形状の接触情報のリンク配列です。
		 * <strong>この変数は外部から変更しないでください。</strong>
		 */
		public var contacts:Contact;
		private var unusedContacts:Contact;
		
		/**
		 * 形状の接触情報の数です。
		 * <strong>この変数は外部から変更しないでください。</strong>
		 */
		public var numContacts:uint;
		
		/**
		 * 接触点の数です。
		 * <strong>この変数は外部から変更しないでください。</strong>
		 */
		public var numContactPoints:uint;
		
		/**
		 * ジョイントの配列です。
		 * <strong>この変数は外部から変更しないでください。</strong>
		 */
		public const joints:Vector.<Joint> = new Vector.<Joint>(MAX_JOINTS, true);
		
		/**
		 * ジョイントの数です。
		 * <strong>この変数は外部から変更しないでください。</strong>
		 */
		public var numJoints:uint;
		
		/**
		 * シミュレーションアイランドの数です。
		 * <strong>この変数は外部から変更しないでください。</strong>
		 */
		public var numIslands:uint;
		
		/**
		 * 1回のステップで進む時間の長さです。
		 */
		public var timeStep:Number;
		
		/**
		 * ワールドにかかる重力です。
		 */
		public var gravity:Vec3;
		
		/**
		 * 衝突応答の反復処理回数です。
		 * 値が大きいほど、より正確な動きになります。
		 */
		public var iteration:uint;
		
		/**
		 * パフォーマンスの詳細情報です。
		 * 計算に要した時間などが記録されています。
		 */
		public var performance:Performance;
		
		/**
		 * 詳細な衝突判定をできるだけ削減するために使用される広域衝突判定です。
		 */
		public var broadPhase:BroadPhase;
		
		private var detectors:Vector.<Vector.<CollisionDetector>>;
		
		private var islandStack:Vector.<RigidBody>;
		private var islandRigidBodies:Vector.<RigidBody>;
		private var islandConstraints:Vector.<Constraint>;
		
		private var randX:uint;
		private var randA:uint;
		private var randB:uint;
		
		/**
		 * 新しく World オブジェクトを作成します。
		 * ワールドのタイムステップは、1秒間でのステップの実行回数から算出されます。
		 * @param stepPerSecond 1秒間でのステップの実行回数
		 */
		public function World(stepPerSecond:Number = 60) {
			timeStep = 1 / stepPerSecond;
			iteration = 8;
			gravity = new Vec3(0, -9.80665, 0);
			performance = new Performance();
			broadPhase = new SweepAndPruneBroadPhase();
			// broadPhase = new DynamicBVTreeBroadPhase();
			// broadPhase = new BruteForceBroadPhase();
			var numShapeTypes:uint = 4;
			detectors = new Vector.<Vector.<CollisionDetector>>(numShapeTypes, true);
			for (var i:int = 0; i < numShapeTypes; i++) {
				detectors[i] = new Vector.<CollisionDetector>(numShapeTypes, true);
			}
			detectors[Shape.SHAPE_SPHERE][Shape.SHAPE_SPHERE] = new SphereSphereCollisionDetector();
			detectors[Shape.SHAPE_SPHERE][Shape.SHAPE_BOX] = new SphereBoxCollisionDetector(false);
			detectors[Shape.SHAPE_SPHERE][Shape.SHAPE_CYLINDER] = new SphereCylinderCollisionDetector(false);
			detectors[Shape.SHAPE_BOX][Shape.SHAPE_SPHERE] = new SphereBoxCollisionDetector(true);
			detectors[Shape.SHAPE_BOX][Shape.SHAPE_BOX] = new BoxBoxCollisionDetector();
			detectors[Shape.SHAPE_CYLINDER][Shape.SHAPE_SPHERE] = new SphereCylinderCollisionDetector(true);
			detectors[Shape.SHAPE_BOX][Shape.SHAPE_CYLINDER] = new BoxCylinderCollisionDetector(false);
			detectors[Shape.SHAPE_CYLINDER][Shape.SHAPE_BOX] = new BoxCylinderCollisionDetector(true);
			detectors[Shape.SHAPE_CYLINDER][Shape.SHAPE_CYLINDER] = new CylinderCylinderCollisionDetector();
			randX = 65535;
			randA = 98765;
			randB = 123456789;
			islandRigidBodies = new Vector.<RigidBody>(64, true);
			islandStack = new Vector.<RigidBody>(64, true);
			islandConstraints = new Vector.<Constraint>(128, true);
		}
		
		/**
		 * ワールドに剛体を追加します。
		 * 追加された剛体はステップ毎の演算対象になります。
		 * @param	rigidBody 追加する剛体
		 */
		public function addRigidBody(rigidBody:RigidBody):void {
			if (rigidBody.parent) {
				throw new Error("一つの剛体を複数ワールドに追加することはできません");
			}
			rigidBody.awake();
			for (var shape:Shape = rigidBody.shapes; shape != null; shape = shape.next) {
				addShape(shape);
			}
			if (rigidBodies != null) (rigidBodies.prev = rigidBody).next = rigidBodies;
			rigidBodies = rigidBody;
			rigidBody.parent = this;
			numRigidBodies++;
		}
		
		/**
		 * ワールドから剛体を削除します。
		 * 削除された剛体はステップ毎の演算対象から外されます。
		 * @param	rigidBody 削除する剛体
		 */
		public function removeRigidBody(rigidBody:RigidBody):void {
			var remove:RigidBody = rigidBody;
			if (remove.parent != this) return;
			remove.awake();
			var js:JointLink = remove.jointLink;
			while (js != null) {
				var joint:Joint = js.parent;
				js = js.next;
				removeJoint(joint);
			}
			for (var shape:Shape = rigidBody.shapes; shape != null; shape = shape.next) {
				removeShape(shape);
			}
			var prev:RigidBody = remove.prev;
			var next:RigidBody = remove.next;
			if (prev != null) prev.next = next;
			if (next != null) next.prev = prev;
			if (rigidBodies == remove) rigidBodies = next;
			remove.parent = null;
			numRigidBodies--;
		}
		
		/**
		 * ワールドに形状を追加します。
		 * <strong>剛体をワールドに追加、およびワールドに追加されている剛体に形状を追加すると、
		 * 自動で形状もワールドに追加されるので、このメソッドは外部から呼ばないでください。</strong>
		 * @param	shape 追加する形状
		 */
		public function addShape(shape:Shape):void {
			if (!shape.parent) {
				throw new Error("ワールドに形状を単体で追加することはできません");
			}
			if (shape.parent.parent) {
				throw new Error("一つの形状を複数ワールドに追加することはできません");
			}
			broadPhase.addProxy(shape.proxy);
		}
		
		/**
		 * ワールドから形状を削除します。
		 * <strong>剛体をワールドから削除、およびワールドに追加されている剛体から形状を削除すると、
		 * 自動で形状もワールドから削除されるので、このメソッドは外部から呼ばないでください。</strong>
		 * @param	shape 削除する形状
		 */
		public function removeShape(shape:Shape):void {
			broadPhase.removeProxy(shape.proxy);
		}
		
		/**
		 * ワールドにジョイントを追加します。
		 * 追加されたジョイントはステップ毎の演算対象になります。
		 * @param	joint 追加するジョイント
		 */
		public function addJoint(joint:Joint):void {
			if (numJoints == MAX_JOINTS) {
				throw new Error("これ以上ワールドにジョイントを追加することはできません");
			}
			if (joint.parent) {
				throw new Error("一つのジョイントを複数ワールドに追加することはできません");
			}
			joint.awake();
			joint.attach();
			joints[numJoints++] = joint;
			joint.parent = this;
		}
		
		/**
		 * ワールドからジョイントを削除します。
		 * 削除されたジョイントはステップ毎の演算対象から外されます。
		 * @param	joint 削除するジョイント
		 * @param	index 削除するジョイントのインデックス
		 */
		public function removeJoint(joint:Joint):void {
			var remove:Joint = null;
			for (var i:int = 0; i < numJoints; i++) {
				if (joints[i] == joint) {
					remove = joint;
					joints[i] = joints[--numJoints];
					joints[numJoints] = null;
					break;
				}
			}
			if (remove == null) return;
			remove.awake();
			remove.detach();
			remove.parent = null;
		}
		
		/**
		 * ワールドの時間をタイムステップ秒だけ進めます。
		 */
		public function step():void {
			var time1:int = getTimer();
			var body:RigidBody = rigidBodies;
			while (body != null) {
				body.addedToIsland = false;
				if (body.sleeping) {
					var lv:Vec3 = body.linearVelocity;
					var av:Vec3 = body.linearVelocity;
					var p:Vec3 = body.position;
					var sp:Vec3 = body.sleepPosition;
					var o:Quat = body.orientation;
					var so:Quat = body.sleepOrientation;
					if (
						lv.x != 0 || lv.y != 0 || lv.z != 0 ||
						av.x != 0 || av.y != 0 || av.z != 0 ||
						p.x != sp.x || p.y != sp.y || p.z != sp.z ||
						o.s != so.s || o.x != so.x || o.y != so.y || o.z != so.z
					){
						body.awake(); // awaking check
					}
				}
				body = body.next;
			}
			updateContacts();
			solveIslands();
			var time2:int = getTimer();
			performance.totalTime = time2 - time1;
			performance.updatingTime = performance.totalTime - (performance.broadPhaseTime + performance.narrowPhaseTime + performance.solvingTime);
		}
		
		private function updateContacts():void {
			// broad phase
			var time1:int = getTimer();
			broadPhase.detectPairs();
			var pairs:Vector.<Pair> = broadPhase.pairs;
			var numPairs:uint = broadPhase.numPairs;
			for (var i:int = 0; i < numPairs; i++) {
				var pair:Pair = pairs[i];
				var s1:Shape;
				var s2:Shape;
				if (pair.shape1.id < pair.shape2.id) {
					s1 = pair.shape1;
					s2 = pair.shape2;
				} else {
					s1 = pair.shape2;
					s2 = pair.shape1;
				}
				
				var link:ContactLink;
				if (s1.numContacts < s2.numContacts) {
					link = s1.contactLink;
				} else {
					link = s2.contactLink;
				}
				var exists:Boolean = false;
				while (link) {
					var contact:Contact = link.parent;
					if (contact.shape1 == s1 && contact.shape2 == s2) {
						contact.persisting = true;
						exists = true; // contact already exists
						break;
					}
					link = link.next;
				}
				if (!exists) {
					var newContact:Contact;
					if (unusedContacts != null) {
						newContact = unusedContacts;
						unusedContacts = unusedContacts.next;
					} else newContact = new Contact();
					newContact.attach(s1, s2);
					newContact.detector = detectors[s1.type][s2.type];
					if (contacts) (contacts.prev = newContact).next = contacts;
					else newContact.next = null;
					contacts = newContact;
					numContacts++;
				}
			}
			
			var time2:int = getTimer();
			performance.broadPhaseTime = time2 - time1;
			
			// update & narrow phase
			numContactPoints = 0;
			contact = contacts;
			while (contact != null) {
				if (!contact.persisting) {
					var prev:Contact = contact.prev;
					var next:Contact = contact.next;
					if (next) next.prev = prev;
					if (prev) prev.next = next;
					if (contacts == contact) contacts = next;
					contact.detach();
					contact.next = unusedContacts;
					unusedContacts = contact;
					contact = next;
					numContacts--;
					continue;
				}
				if (!contact.body1.sleeping || !contact.body2.sleeping) {
					contact.updateManifold();
				}
				numContactPoints += contact.manifold.numPoints;
				contact.persisting = false;
				contact.constraint.addedToIsland = false;
				contact = contact.next;
			}
			
			var time3:int = getTimer();
			performance.narrowPhaseTime = time3 - time2;
		}
		
		private function solveIslands():void {
			var invTimeStep:Number = 1 / timeStep;
			var body:RigidBody;
			var constraint:Constraint;
			var num:uint;
			
			for (var i:int = 0; i < numJoints; i++) {
				joints[i].addedToIsland = false;
			}
			
			// expand island buffers
			if (islandRigidBodies.length < numRigidBodies) {
				islandRigidBodies = new Vector.<RigidBody>(numRigidBodies << 1, true);
				islandStack = new Vector.<RigidBody>(numRigidBodies << 1, true);
			}
			var numConstraints:uint = numJoints + numContacts;
			if (islandConstraints.length < numConstraints) {
				islandConstraints = new Vector.<Constraint>(numConstraints << 1, true);
			}
			
			var time1:int = getTimer();
			numIslands = 0;
			// build and solve simulation islands
			var base:RigidBody = rigidBodies;
			while (base != null) {
				if (base.addedToIsland || base.isStatic || base.sleeping) {
					base = base.next;
					continue; // ignore
				}
				var islandNumRigidBodies:uint = 0;
				var islandNumConstraints:uint = 0;
				var stackCount:uint = 1;
				// add rigid body to stack
				islandStack[0] = base;
				base.addedToIsland = true;
				// build an island
				while (stackCount > 0) {
					// get rigid body from stack
					body = islandStack[--stackCount];
					islandStack[stackCount] = null; // gc
					body.sleeping = false;
					// add rigid body to the island
					islandRigidBodies[islandNumRigidBodies++] = body;
					if (body.isStatic) {
						continue;
					}
					// search connections
					for (var cs:ContactLink = body.contactLink; cs != null; cs = cs.next) {
						var contact:Contact = cs.parent;
						constraint = contact.constraint;
						if (constraint.addedToIsland || !contact.touching) {
							continue; // ignore
						}
						// add constraint to the island
						islandConstraints[islandNumConstraints++] = constraint;
						constraint.addedToIsland = true;
						var next:RigidBody = cs.body;
						if (next.addedToIsland) {
							continue;
						}
						// add rigid body to stack
						islandStack[stackCount++] = next;
						next.addedToIsland = true;
					}
					for (var js:JointLink = body.jointLink; js != null; js = js.next) {
						constraint = js.parent;
						if (constraint.addedToIsland) {
							continue; // ignore
						}
						// add constraint to the island
						islandConstraints[islandNumConstraints++] = constraint;
						constraint.addedToIsland = true;
						next = js.body;
						if (next.addedToIsland || !next.isDynamic) {
							continue;
						}
						// add rigid body to stack
						islandStack[stackCount++] = next;
						next.addedToIsland = true;
					}
				}
				// update the island
				
				// update velocities
				var gx:Number = gravity.x * timeStep;
				var gy:Number = gravity.y * timeStep;
				var gz:Number = gravity.z * timeStep;
				for (var j:int = 0; j < islandNumRigidBodies; j++) {
					body = islandRigidBodies[j];
					if (body.isDynamic) {
						body.linearVelocity.x += gx;
						body.linearVelocity.y += gy;
						body.linearVelocity.z += gz;
					}
				}
				
				// randomizing order TODO: it should be able to be disabled by simulation setting
				for (j = 1; j < islandNumConstraints; j++) {
					var swap:uint = (randX = (randX * randA + randB & 0x7fffffff)) / 2147483648.0 * j | 0;
					constraint = islandConstraints[j];
					islandConstraints[j] = islandConstraints[swap];
					islandConstraints[swap] = constraint;
				}
				
				// solve contraints
				for (j = 0; j < islandNumConstraints; j++) {
					islandConstraints[j].preSolve(timeStep, invTimeStep); // pre-solve
				}
				for (var k:int = 0; k < iteration; k++) {
					for (j = 0; j < islandNumConstraints; j++) {
						islandConstraints[j].solve(); // main-solve
					}
				}
				for (j = 0; j < islandNumConstraints; j++) {
					islandConstraints[j].postSolve(); // post-solve
					islandConstraints[j] = null; // gc
				}
				
				// sleeping check
				var sleepTime:Number = 10;
				for (j = 0; j < islandNumRigidBodies; j++) {
					body = islandRigidBodies[j];
					if (!body.allowSleep) {
						body.sleepTime = 0;
						sleepTime = 0;
						continue;
					}
					var vx:Number = body.linearVelocity.x;
					var vy:Number = body.linearVelocity.y;
					var vz:Number = body.linearVelocity.z;
					if (vx * vx + vy * vy + vz * vz > 0.04) {
						body.sleepTime = 0;
						sleepTime = 0;
						continue;
					}
					vx = body.angularVelocity.x;
					vy = body.angularVelocity.y;
					vz = body.angularVelocity.z;
					if (vx * vx + vy * vy + vz * vz > 0.25) {
						body.sleepTime = 0;
						sleepTime = 0;
						continue;
					}
					body.sleepTime += timeStep;
					if (body.sleepTime < sleepTime) sleepTime = body.sleepTime;
				}
				if (sleepTime > 0.5) {
					// sleep the island
					for (j = 0; j < islandNumRigidBodies; j++) {
						islandRigidBodies[j].sleep();
						islandRigidBodies[j] = null; // gc
					}
				} else {
					// update positions
					for (j = 0; j < islandNumRigidBodies; j++) {
						islandRigidBodies[j].updatePosition(timeStep);
						islandRigidBodies[j] = null; // gc
					}
				}
				numIslands++;
				base = base.next;
			}
			var time2:int = getTimer();
			performance.solvingTime = time2 - time1;
		}
		
	}

}