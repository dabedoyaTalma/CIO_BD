/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesStaircaseV2]    Script Date: 09/05/2023 14:24:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ========================================================================================================================================================================
-- Description: Function for Businees Rules "Services Staircase v2" 
--
-- Change History:
--	2019-10-29  Diomer Bedoya: Funtion created
--	2021-08-31	Sebastián Jaramillo: Se adiciona RN VivaAerobus
--	2021-12-06	Sebastián Jaramillo: Nueva RN American Airlines	
--	2021-12-15	Sebastián Jaramillo: Ajuste RN American Airlines
--	2022-01-31	Sebastián Jaramillo: Nueva RN Ultra Air
--	2022-04-29	Sebastián Jaramillo: Se ajusta RN VivaAerobus incluyendo MDE como un nuevo aeropuerto
--	2022-09-28	Sebastián Jaramillo: Se adicionan RN Arajet
--	2022-11-11	Sebastián Jaramillo: Se incluye RN para el cliente Aerolineas Argentinas
--	2023-02-13	Sebastián Jaramillo: Se configura nuevo contrato de Avianca 2023 "TAKE OFF 20230201" y Regional Express se integra como un "facturar a" más de Avianca
--	2023-03-30	Sebastián Jaramillo: Adición de RN RCH LATAM
--	2023-04-20	Sebastián Jaramillo: Fusión TALMA-SAI BOGEX Incorporación RN AVA estaciones (BGA, MTR, PSO, IBE, NVA) Compañía: Avianca - Facturar a: SAI
-- ========================================================================================================================================================================

--SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesStaircaseV2](33442,3,1,1,23,'2019-08-12')
--SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesStaircaseV2](19482,3,1,1,1,'2019-10-01')
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesStaircaseV2](
	@ServiceHeaderId BIGINT,
	@AirportId INT,
	@CompanyId INT,
	@BillingToCompany INT,
	@ServiceTypeId INT,
	@DateService DATE
)
RETURNS @T_Result TABLE(ROW INT IDENTITY, StartDate DATETIME, EndDate DATETIME, Time INT, AdditionalService BIT, AdditionalStartHour DATETIME, AdditionalEndHour DATETIME, AdditionalTime INT, AdditionalQuantity INT, AdditionalServiceName VARCHAR(150), Fraction VARCHAR(25), TimeLeftover INT)
AS
BEGIN
	DECLARE	@SeUsoEscaleraDelantera BIT = 0
	DECLARE	@SeUsoEscaleraTrasera BIT = 0

	DECLARE @T_TMP_DETALLE_SRV_ESC_DELAN AS CIOReglaNegocio.ServiceDetailType --TIPO DEFINIDO
	DECLARE @T_TMP_DETALLE_SRV_ESC_TRAS AS CIOReglaNegocio.ServiceDetailType --TIPO DEFINIDO

	DECLARE @MinDatetimeFromTimeline DATETIME2(0)
    DECLARE @MaxDatetimeFromTimeline DATETIME2(0)

	DECLARE	@T_TMP_DETALLE_SRV AS CIOReglaNegocio.ServiceDetailType --TIPO DEFINIDO

	INSERT	@T_TMP_DETALLE_SRV_ESC_DELAN
	SELECT	ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) fila,
			'ESCALERA DE ABORDAJE',
			DS.FechaInicio, 
			DS.FechaFin, 
			DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) Time_total, 
			ISNULL(DS.cantidad, 1) cantidad
	FROM	CIOServicios.DetalleServicio DS
	WHERE	DS.Activo = 1 AND
			DS.TipoActividadId = 116 AND --EVENTOS ESCALERA PARA CONTROL AT
			ISNULL(DS.PropietarioId, 1) IN (1, 3/*, 99*/) AND --PROPIETARIO EQUIPO SEA LASA U OTRO TERCERO
			DS.EncabezadoServicioId = @ServiceHeaderId

			IF (@@ROWCOUNT > 0)
				SET	@SeUsoEscaleraDelantera = 1

	INSERT	@T_TMP_DETALLE_SRV_ESC_TRAS
	SELECT	ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) fila,
			'ESCALERA DE ABORDAJE',
			DS.FechaInicio, 
			DS.FechaFin, 
			DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) Time_total, 
			ISNULL(DS.cantidad, 1) cantidad
	FROM	CIOServicios.DetalleServicio DS
	WHERE	DS.Activo = 1 AND
			DS.TipoActividadId = 117 AND --EVENTOS ESCALERA PARA CONTROL AT
			ISNULL(DS.PropietarioId, 1) IN (1, 3/*, 99*/) AND --PROPIETARIO EQUIPO SEA LASA U OTRO TERCERO
			DS.EncabezadoServicioId = @ServiceHeaderId

			IF (@@ROWCOUNT > 0)
				SET	@SeUsoEscaleraTrasera = 1

	IF (@CompanyId = 67 AND @BillingToCompany = 67) --AEROLINEAS ARGENTINAS / AEROLINEAS ARGENTINAS	
	BEGIN
		IF (@DateService >= '2022-11-01')
		BEGIN
			INSERT	@T_TMP_DETALLE_SRV
			SELECT	ROW_NUMBER() OVER(ORDER BY HoraInicio) Fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, Cantidad
			FROM	(	SELECT	Fila, CONCAT(Servicio, ' DELANTERA') Servicio, HoraInicio, HoraFinal, TiempoTotal, Cantidad
						FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
						UNION	ALL
						SELECT	Fila, CONCAT(Servicio, ' TRASERA') Servicio, HoraInicio, HoraFinal, TiempoTotal, Cantidad 
						FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
					) AS R

			IF(@SeUsoEscaleraDelantera = 1 AND @SeUsoEscaleraTrasera = 1)
			BEGIN
				IF EXISTS(SELECT TOP(1) Servicio FROM @T_TMP_DETALLE_SRV WHERE Fila = 1 AND Servicio LIKE '%DELANTERA') --Se valida si la escalera que se conectó primero fue la delantera
				BEGIN
					DELETE FROM @T_TMP_DETALLE_SRV WHERE Servicio LIKE '%DELANTERA' --Se descarta cobro de la escalera delantera que se conectó primero por ir 1 incluida

					INSERT @T_Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@T_TMP_DETALLE_SRV, 0, 60.0,NULL,NULL)
				END

				IF EXISTS(SELECT TOP(1) Servicio FROM @T_TMP_DETALLE_SRV WHERE Fila = 1 AND Servicio LIKE '%TRASERA') --Se valida si la escalera que se conectó primero fue la trasera
				BEGIN
					DELETE FROM @T_TMP_DETALLE_SRV WHERE Servicio LIKE '%TRASERA' --Se descarta cobro de la escalera trasera que se conectó primero por ir 1 incluida

					INSERT @T_Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@T_TMP_DETALLE_SRV, 0, 60.0,NULL,NULL)
				END
			END

			RETURN
		END
	END

	--ARAJET / ARAJET
	IF (@CompanyId=272 AND @BillingToCompany=272)
	BEGIN
		IF (@DateService >= '2022-09-15')
		BEGIN
			RETURN --El cliente Ultra tiene las 2 escaleras incluidas
		END
	END

	--ULTRA AIR / ULTRA AIR
	IF (@CompanyId=259 AND @BillingToCompany=259)
	BEGIN
		IF (@DateService >= '2022-01-20')
		BEGIN
			RETURN --El cliente Ultra tiene las 2 escaleras incluidas
		END
	END

	IF (@CompanyId=43 AND @BillingToCompany=43) --AMERICAN AIRLINES / AMERICAN AIRLINES
	BEGIN
		IF (@DateService >= '2021-12-04')
		BEGIN
			INSERT	@T_TMP_DETALLE_SRV
			SELECT	ROW_NUMBER() OVER(ORDER BY HoraInicio) Fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, Cantidad
			FROM	(	SELECT	Fila, CONCAT(Servicio, ' DELANTERA') Servicio, HoraInicio, HoraFinal, TiempoTotal, Cantidad
						FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
						UNION	ALL
						SELECT	Fila, CONCAT(Servicio, ' TRASERA') Servicio, HoraInicio, HoraFinal, TiempoTotal, Cantidad 
						FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
					) AS R

			IF(@SeUsoEscaleraDelantera = 1 AND @SeUsoEscaleraTrasera = 1)
			BEGIN
				IF EXISTS(SELECT TOP(1) Servicio FROM @T_TMP_DETALLE_SRV WHERE Fila = 1 AND Servicio LIKE '%DELANTERA') --Se valida si la escalera que se conectó primero fue la delantera
				BEGIN
					DELETE FROM @T_TMP_DETALLE_SRV WHERE Servicio LIKE '%DELANTERA' --Se descarta cobro de la escalera delantera que se conectó primero por ir 1 incluida

					INSERT @T_Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@T_TMP_DETALLE_SRV, 0, 30.0,NULL,NULL)
				END

				IF EXISTS(SELECT TOP(1) Servicio FROM @T_TMP_DETALLE_SRV WHERE Fila = 1 AND Servicio LIKE '%TRASERA') --Se valida si la escalera que se conectó primero fue la trasera
				BEGIN
					DELETE FROM @T_TMP_DETALLE_SRV WHERE Servicio LIKE '%TRASERA' --Se descarta cobro de la escalera trasera que se conectó primero por ir 1 incluida

					INSERT @T_Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@T_TMP_DETALLE_SRV, 0, 30.0,NULL,NULL)
				END
			END

			RETURN
		END
	END

	IF (@CompanyId = 1 AND @BillingToCompany = 87) --AVIANCA A SAI
	BEGIN
		IF (@DateService >= '2023-04-19' AND @AirportId IN (11, 40, 47, 31, 43)) --BGA, MTR, PSO, IBE, NVA
		BEGIN
			IF (@ServiceTypeId IN (1, 2, 3, 4)) --ETAPAS DE TRANSITO Y PERNOCTA
			BEGIN
				IF (	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_RemoteGateArrival](@ServiceHeaderId) = 1 --Si se recibe en remota
					OR	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_RemoteGateDeparture](@ServiceHeaderId) = 1 --o si sale en remota
					)
				BEGIN
					--En remota incluye 2 escalaras
					INSERT	@T_TMP_DETALLE_SRV
					SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
					FROM	(	SELECT	* 
								FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
								UNION	ALL
								SELECT	* 
								FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
							) AS R

					INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 2) WHERE AdditionalAmount > 0
				END
				ELSE
				BEGIN
					--En posicion normal 1 sola escalera

					INSERT	@T_TMP_DETALLE_SRV
					SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
					FROM	(	SELECT	* 
								FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
								UNION	ALL
								SELECT	* 
								FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
							) AS R

					INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 1) WHERE AdditionalAmount > 0
				END
			END
			ELSE
			BEGIN
				--Para los demás tipos de servicio NO hay escaleras incluidas

				INSERT	@T_TMP_DETALLE_SRV
				SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
				FROM	(	SELECT	* 
							FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
							UNION	ALL
							SELECT	* 
							FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
						) AS R

				INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 0) WHERE AdditionalAmount > 0
			END
		
			RETURN
		END
	END

	IF (	(@CompanyId = 1 AND @BillingToCompany = 1)  --AVIANCA S.A A AVIANCA S.A
		OR	(@CompanyId = 1 AND @BillingToCompany = 193)  --AVIANCA S.A A REGIONAL EXPRESS
		OR	(@CompanyId = 42 AND @BillingToCompany = 1) --TACA A AVIANCA S.A.
		OR	(@CompanyId = 47 AND @BillingToCompany = 1) --AEROGAL S.A A AVIANCA S.A.
	)
	BEGIN
		IF (@DateService >= '2023-02-01')
		BEGIN
			IF (@ServiceTypeId IN (1, 2, 3, 4)) --ETAPAS DE TRANSITO Y PERNOCTA
			BEGIN
				IF (	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_RemoteGateArrival](@ServiceHeaderId) = 1 --Si se recibe en remota
					OR	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_RemoteGateDeparture](@ServiceHeaderId) = 1 --o si sale en remota
					)
				BEGIN
					--En remota incluye 2 escalaras
					INSERT	@T_TMP_DETALLE_SRV
					SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
					FROM	(	SELECT	* 
								FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
								UNION	ALL
								SELECT	* 
								FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
							) AS R

					INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 2) WHERE AdditionalAmount > 0
				END
				ELSE
				BEGIN
					--En posicion normal 1 sola escalera

					INSERT	@T_TMP_DETALLE_SRV
					SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
					FROM	(	SELECT	* 
								FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
								UNION	ALL
								SELECT	* 
								FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
							) AS R

					INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 1) WHERE AdditionalAmount > 0
				END
			END
			ELSE
			BEGIN
				--Para los demás tipos de servicio NO hay escaleras incluidas

				INSERT	@T_TMP_DETALLE_SRV
				SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
				FROM	(	SELECT	* 
							FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
							UNION	ALL
							SELECT	* 
							FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
						) AS R

				INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 0) WHERE AdditionalAmount > 0
			END
		
			RETURN
		END
	END

	IF (@CompanyId = 193 AND @BillingToCompany = 1) --REGIONAL EXPRESS A AVIANCA (QUEDA OBSOLETA PORQUE YA REGIONAL NO SE MANEJA COMO COMPAÑIA INDEPENDIENTE SE MANEJA COMO UN FACTURAR A MAS DE AVIANCA
	BEGIN
		INSERT	@T_TMP_DETALLE_SRV
		SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
		FROM	(	SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
					UNION	ALL
					SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
				) AS R

		INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 1) WHERE AdditionalAmount > 0

		RETURN
	END

	IF (@CompanyId = 43 AND @BillingToCompany = 1) --AMERICAN AIRLINES A AVIANCA
	BEGIN
		INSERT	@T_TMP_DETALLE_SRV
		SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
		FROM	(	SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
					UNION	ALL
					SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
				) AS R

		INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 1) WHERE AdditionalAmount > 0

		RETURN
	END

	IF (@CompanyId = 1 AND @BillingToCompany = 87) --AVIANCA A SAI
	BEGIN
		IF (@DateService >= '2021-10-27' AND @AirportId = 12) --BOG
		BEGIN
			INSERT	@T_TMP_DETALLE_SRV
			SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
			FROM	(	SELECT	* 
						FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
						UNION	ALL
						SELECT	* 
						FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
					) AS R

			INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 0) WHERE AdditionalAmount > 0

			RETURN
		END
	END

	IF (@CompanyId = 51 AND @BillingToCompany = 51 AND @DateService >= '2020-02-01') --LANCO
	BEGIN	
		--LA ESCALERA DELANTERA ESTA INCLUIDA

		--LA ESCALERA TRASERA NO ESTÁ INCLUIDA
		INSERT @T_Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@T_TMP_DETALLE_SRV_ESC_TRAS, 0, 30.0,NULL,NULL)

		RETURN
	END

	IF (@BillingToCompany IN (1, 41, 42, 54, 193, 47)) --AVIANCA, LACSA, TACA, TRANS, AEROGAL TODO PREGUNTAR 194
	BEGIN
		INSERT @T_Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@T_TMP_DETALLE_SRV_ESC_DELAN, 0, 30.0,NULL,NULL)
		INSERT @T_Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@T_TMP_DETALLE_SRV_ESC_TRAS, 0, 30.0,NULL,NULL)

		RETURN
	END

	IF (@CompanyId = 9 AND @BillingToCompany = 9) --COPA
	BEGIN
		INSERT	@T_TMP_DETALLE_SRV
		SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
		FROM	(	SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
					UNION	ALL
					SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
				) AS R

		IF (@AirportId = 5 AND @DateService >= '2017-04-16') --ADZ, a partir de esta fecha se empieza a cobrar adicional en esta base
		BEGIN
			INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 0) WHERE AdditionalAmount > 0

			RETURN
		END

		--PARA EL RESTO DE BASES DE COPA LAS ESCALERAS LAS PROEEVEN ELLOS MISMOS POR EL MOMENTO NO SE LES COBRAN ADICIONALES

		RETURN
	END

	IF (@CompanyId = 81 AND @BillingToCompany = 81) --JET SMART
	BEGIN
		INSERT @T_Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@T_TMP_DETALLE_SRV, 0, 30,NULL,NULL) -- DESDE MINUTO 0 PARA JET SMART POR FRACCION 30

		RETURN
	END

	IF (@CompanyId = 44 AND @BillingToCompany IN (44, 139)) --LATAM LAN, LAN PERU 
	BEGIN
		INSERT	@T_TMP_DETALLE_SRV
		SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio,HoraInicio , HoraFinal, TiempoTotal, cantidad
		FROM	(	SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
					UNION	ALL
					SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
				) AS R

		IF (@ServiceTypeId = 14) --LIMPIEZAS TERMINALES
		BEGIN
			INSERT @T_Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@T_TMP_DETALLE_SRV, 120, 30,NULL,NULL) --MANTENIMIENTO LAN 2 HORAS INCLUIDAS ADICIONALES POR FRACCION 30

			RETURN
		END

		IF (@AirportId IN (5, 18, 45, 55)) --ADZ, CUC, PEI, SMR
		BEGIN
			INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 1) WHERE AdditionalAmount > 0

			RETURN
		END

		IF (@AirportId IN(11, 17, 25, 34, 40, 59, 51)) --BGA, CTG, EYP, LET, MTR, VUP, RCH
		BEGIN
			INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 2) WHERE AdditionalAmount > 0

			RETURN
		END

		RETURN
	END

	IF (@CompanyId = 72 AND @BillingToCompany = 56 AND @ServiceTypeId IN (2,3)) --WINGO
	BEGIN
	     
		SELECT @MinDatetimeFromTimeline = MIN(InicioReal) FROM CIOServicios.LineaTiempoXEncabezadoServicio WHERE EncabezadoServicioId = @ServiceHeaderId AND EtapaTipoServicioId = 2 AND Activo = 1
        SELECT @MaxDatetimeFromTimeline = MAX(FinReal) FROM CIOServicios.LineaTiempoXEncabezadoServicio WHERE EncabezadoServicioId = @ServiceHeaderId AND EtapaTipoServicioId = 3 AND Activo = 1
			    
		INSERT	@T_TMP_DETALLE_SRV
		SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
		FROM	(	SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_DELAN WHERE HoraInicio >= @MinDatetimeFromTimeline AND HoraFinal <= @MaxDatetimeFromTimeline
					UNION	ALL
					SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_TRAS WHERE HoraInicio >= @MinDatetimeFromTimeline AND HoraFinal <= @MaxDatetimeFromTimeline
				) AS R

		INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 1) WHERE AdditionalAmount > 0

		RETURN
	END
	
	IF (@CompanyId = 72 AND @BillingToCompany = 56 AND @ServiceTypeId IN (4)) --WINGO
	BEGIN

		SELECT @MinDatetimeFromTimeline = MIN(InicioReal) FROM CIOServicios.LineaTiempoXEncabezadoServicio WHERE EncabezadoServicioId = @ServiceHeaderId AND EtapaTipoServicioId = 4 AND Activo = 1
        SELECT @MaxDatetimeFromTimeline = MAX(FinReal) FROM CIOServicios.LineaTiempoXEncabezadoServicio WHERE EncabezadoServicioId = @ServiceHeaderId AND EtapaTipoServicioId = 4 AND Activo = 1

		INSERT	@T_TMP_DETALLE_SRV
		SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
		FROM	(	SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_DELAN WHERE HoraInicio >= @MinDatetimeFromTimeline AND HoraFinal <= @MaxDatetimeFromTimeline
					UNION	ALL
					SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_TRAS WHERE HoraInicio >= @MinDatetimeFromTimeline AND HoraFinal <= @MaxDatetimeFromTimeline
				) AS R

		INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 1) WHERE AdditionalAmount > 0

		RETURN
	END

	IF (@CompanyId = 205 AND @BillingToCompany = 205) --ARUBA AIRLINES
	BEGIN
		INSERT	@T_TMP_DETALLE_SRV
		SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
		FROM	(	SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
					UNION	ALL
					SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
				) AS R

		INSERT @T_Result SELECT StartTime, FinalTime, NULL, AdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 1) WHERE AdditionalAmount > 0

		RETURN
	END

	IF (@CompanyId = 70 AND @BillingToCompany = 70) --INTERJET
	BEGIN
		IF(@AirportId = 17)-- Cartagena
		BEGIN
			INSERT	@T_TMP_DETALLE_SRV
			SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
			FROM	(	SELECT	* 
						FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
						UNION	ALL
						SELECT	* 
						FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
					) AS R

				
			INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 2) WHERE AdditionalAmount > 0
		END
		ELSE
		BEGIN
			INSERT	@T_TMP_DETALLE_SRV
			SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
			FROM	(	SELECT	* 
						FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
						UNION	ALL
						SELECT	* 
						FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
					) AS R

				
			INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 1) WHERE AdditionalAmount > 0
			RETURN
		END
		RETURN
	END

	IF (@CompanyId = 205 AND @BillingToCompany = 205) --GRAN COLOMBIA DE AVIACION (GCA)
	BEGIN
		INSERT	@T_TMP_DETALLE_SRV
		SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
		FROM	(	SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
					UNION	ALL
					SELECT	* 
					FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
				) AS R

		INSERT @T_Result SELECT StartTime, FinalTime, NULL, AdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 0) WHERE AdditionalAmount > 0

		RETURN
	END

	IF (@CompanyId = 255 AND @BillingToCompany = 255) --VIVAAEROBUS
	BEGIN
		IF (@DateService >= '2021-08-21')
		BEGIN
			DECLARE @CantidadEscalerasIncluidas INT = NULL --OJO!! NECESARIO PARA VALIDACIONES MAS ABAJO

			IF (@DateService >= '2021-08-21' AND @AirportId = 12) --BOG
			BEGIN
				IF ([CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_RemoteGateArrival](@ServiceHeaderId) = 0)
				BEGIN
					SET @CantidadEscalerasIncluidas = 0 --En muelles en BOG no se incluye nada
				END
				ELSE
				BEGIN
					SET @CantidadEscalerasIncluidas = 2 --En posiciones remotas en BOG se incluyen 2 escaleras
				END
			END

			IF (@DateService >= '2022-04-08' AND @AirportId = 3) --MDE
			BEGIN
				SET @CantidadEscalerasIncluidas = 2 --Se incluyen 2 escaleras en MDE
			END

			IF (@CantidadEscalerasIncluidas IS NULL)
			BEGIN
				SET @CantidadEscalerasIncluidas = 0 --Para los aeropuertos alternos no se incluye nada
			END		

			INSERT	@T_TMP_DETALLE_SRV
			SELECT	ROW_NUMBER() OVER(ORDER BY fila) fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, cantidad
			FROM	(	SELECT	* 
						FROM	@T_TMP_DETALLE_SRV_ESC_DELAN 
						UNION	ALL
						SELECT	* 
						FROM	@T_TMP_DETALLE_SRV_ESC_TRAS
					) AS R
			
			INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, @CantidadEscalerasIncluidas) WHERE AdditionalAmount > 0

			RETURN
		END

		RETURN
	END

	RETURN
END